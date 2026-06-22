import json
import os
import time
import boto3
from botocore.exceptions import ClientError
from concurrent.futures import ThreadPoolExecutor, as_completed

AWS_REGION = os.environ.get('AWS_REGION', 'eu-west-2')
METADATA_TABLE = os.environ.get('METADATA_TABLE', 'whatson-database-metadata')
ORIGIN_VERIFY_SECRET_ARN = os.environ.get('ORIGIN_VERIFY_SECRET_ARN', '')

# In-memory cache for the origin-verify secret (avoids calling Secrets Manager every request)
_origin_secret_cache = {'value': None, 'fetched_at': 0}
ORIGIN_SECRET_CACHE_TTL = 300  # seconds (5 minutes)

CROSS_ACCOUNT_ROLES = [
    arn.strip() for arn in os.environ.get('CROSS_ACCOUNT_ROLES', '').split(',') if arn.strip()
]

sts_client = boto3.client('sts', region_name=AWS_REGION)
local_session = boto3.Session(region_name=AWS_REGION)
secrets_client = boto3.client('secretsmanager', region_name=AWS_REGION)

# DynamoDB client (always in local account)
dynamodb = boto3.resource('dynamodb', region_name=AWS_REGION)
metadata_table = dynamodb.Table(METADATA_TABLE)


# ENTRY POINT

def lambda_handler(event, context):
    headers = event.get('headers') or {}
    origin_verify = headers.get('x-origin-verify', '')
    expected_secret = _get_origin_verify_secret()
    if expected_secret and origin_verify != expected_secret:
        return _response(403, {'error': 'Forbidden'})

    try:
        route_key = event.get('routeKey', '')
        path_params = event.get('pathParameters', {}) or {}

        if route_key == 'GET /databases':
            return list_databases()

        elif route_key == 'GET /databases/{instanceName}':
            return get_database_detail(path_params.get('instanceName'))

        elif route_key == 'PUT /databases/{instanceName}/metadata':
            return update_metadata(path_params.get('instanceName'), event.get('body'))

        return _response(404, {'error': f'Route not found: {route_key}'})

    except Exception as e:
        print(f"Unhandled error: {e}")
        return _response(500, {'error': 'Internal server error'})


# ACCOUNT HANDLING

def _get_local_account_id():
    return sts_client.get_caller_identity()['Account']


def _assume_role(role_arn):
    try:
        account_id = role_arn.split(':')[4]

        response = sts_client.assume_role(
            RoleArn=role_arn,
            RoleSessionName='DashboardSession',
            DurationSeconds=900
        )

        creds = response['Credentials']

        session = boto3.Session(
            aws_access_key_id=creds['AccessKeyId'],
            aws_secret_access_key=creds['SecretAccessKey'],
            aws_session_token=creds['SessionToken'],
            region_name=AWS_REGION
        )

        return {
            'session': session,
            'account_id': account_id
        }

    except ClientError as e:
        print(f"Failed to assume role {role_arn}: {e}")
        raise


def _determine_environment(identifier):
    val = (identifier or '').lower()
    if 'nonprod' in val or 'non-prod' in val:
        return 'Non-Production'
    if 'prod' in val:
        return 'Production'
    return 'Non-Production'


def _get_account_alias(session, account_id):
    """Fetches the AWS account alias. Returns account_id if no alias set."""
    try:
        iam = session.client('iam')
        aliases = iam.list_account_aliases().get('AccountAliases', [])
        return aliases[0] if aliases else account_id
    except ClientError as e:
        print(f"[ALIAS ERROR] Could not fetch alias for {account_id}: {e}")
        return account_id


def _iterate_accounts():
    # Local
    local_account_id = _get_local_account_id()
    local_alias = _get_account_alias(local_session, local_account_id)
    yield {
        'session': local_session,
        'account_id': local_account_id,
        'environment': _determine_environment(local_alias)
    }

    # Cross accounts
    for role_arn in CROSS_ACCOUNT_ROLES:
        try:
            acc = _assume_role(role_arn)
            alias = _get_account_alias(acc['session'], acc['account_id'])
            acc['environment'] = _determine_environment(alias)
            yield acc
        except Exception as e:
            print(f"Skipping role {role_arn}: {e}")


# DYNAMODB METADATA

def _get_all_metadata():
    """
    Fetches all metadata items from DynamoDB.
    Returns a dict keyed by instanceName for quick lookup.
    """
    try:
        response = metadata_table.scan()
        items = response.get('Items', [])

        while 'LastEvaluatedKey' in response:
            response = metadata_table.scan(ExclusiveStartKey=response['LastEvaluatedKey'])
            items.extend(response.get('Items', []))

        return {item['instanceName']: item for item in items}

    except ClientError as e:
        print(f"Error scanning metadata table: {e}")
        return {}


def _get_metadata_for(instance_name):
    """Fetches metadata for a single instance from DynamoDB. Returns {} if not found."""
    try:
        response = metadata_table.get_item(Key={'instanceName': instance_name})
        return response.get('Item', {})
    except ClientError as e:
        print(f"Error fetching metadata for {instance_name}: {e}")
        return {}


def _save_metadata(instance_name, metadata_dict):
    """Saves metadata to DynamoDB.
    Includes user-editable fields AND auto-cached snapshot fields"""
    item = {
        'instanceName': instance_name,
        'applicationVersion': metadata_dict.get('applicationVersion', ''),
        'lastUpgradeDate': metadata_dict.get('lastUpgradeDate', ''),
        'owner': metadata_dict.get('owner', ''),
        'functionality': metadata_dict.get('functionality', ''),
        # Auto-cached fields (snapshot info from events)
        'sourceSnapshot': metadata_dict.get('sourceSnapshot', ''),
        'sourceInstance': metadata_dict.get('sourceInstance', ''),
        'cachedCreationDate': metadata_dict.get('cachedCreationDate', ''),
        'updatedAt': int(time.time())
    }

    metadata_table.put_item(Item=item)
    return item


# RDS FETCH

def _fetch_databases_no_metadata(session, account_id, environment):
    """
    Used by parallel executor — metadata is merged after all results return.
    """
    rds = session.client('rds')
    databases = []

    try:
        paginator = rds.get_paginator('describe_db_instances')

        for page in paginator.paginate():
            for db in page.get('DBInstances', []):
                databases.append({
                    'databaseName': db.get('DBName', ''),
                    'instanceName': db.get('DBInstanceIdentifier', ''),
                    'status': db.get('DBInstanceStatus', ''),
                    'creationDate': _format_date(db.get('InstanceCreateTime')),
                    'sourceInstance': db.get('ReadReplicaSourceDBInstanceIdentifier', ''),
                    'oracleVersion': db.get('EngineVersion', ''),
                    'environment': environment,
                    'accountId': account_id,
                    # Metadata fields filled in by parallel merge in list_databases()
                    'owner': '',
                    'functionality': '',
                    'appVersion': '',
                    'lastUpgrade': ''
                })

    except ClientError as e:
        print(f"Error fetching DBs from {account_id}: {e}")

    return databases


def _get_restore_info_from_events(rds_client, instance_name):
    """
    Calls describe_events to find the MOST RECENT 'Restored from snapshot' event.
    Paginates through ALL events in the 14-day window.
    Returns dict with sourceSnapshot and sourceInstance, or empty strings.
    """
    result = {'sourceSnapshot': '', 'sourceInstance': ''}

    try:
        paginator = rds_client.get_paginator('describe_events')
        page_iterator = paginator.paginate(
            SourceIdentifier=instance_name,
            SourceType='db-instance',
            Duration=20160  # 14 days
        )

        # Find the LATEST restore event across ALL pages
        # (events are returned oldest-first by AWS, so keep overwriting → final = newest)
        latest_snapshot = None

        for page in page_iterator:
            for event in page.get('Events', []):
                message = event.get('Message', '')
                if message.startswith('Restored from snapshot '):
                    latest_snapshot = message.replace('Restored from snapshot ', '').strip()

        if latest_snapshot:
            result['sourceSnapshot'] = latest_snapshot
            result['sourceInstance'] = _parse_source_instance(latest_snapshot)

    except ClientError as e:
        print(f"Error fetching events for {instance_name}: {e}")

    return result


def _parse_source_instance(snapshot_name):
    """
    Extracts the source instance name from a snapshot name.

    Examples:
      bruce-twdcemea-wonprd-20260525-0030-3051-cpy-reencrypted → twdcemea-wonprd
      rds:twdcemea-postprod-2026-05-12-03-14                  → twdcemea-postprod
      twdcemea-wonuat-manual-snapshot                          → twdcemea-wonuat

    Looks for the 'twdcemea-xxx' pattern. Returns '' if not found.
    """
    if not snapshot_name:
        return ''

    name = snapshot_name
    if name.startswith('rds:'):
        name = name[4:]  # Strip automated-snapshot prefix

    parts = name.split('-')
    for i, part in enumerate(parts):
        if part == 'twdcemea' and i + 1 < len(parts):
            return f"twdcemea-{parts[i + 1]}"

    return ''


def _fetch_single_db(session, instance_name):
    rds = session.client('rds')

    try:
        response = rds.describe_db_instances(DBInstanceIdentifier=instance_name)
        db = response['DBInstances'][0]
        endpoint = db.get('Endpoint') or {}

        # Current creation date from RDS (changes when DB is restored)
        current_creation_date = _format_date(db.get('InstanceCreateTime'))

        # Get cached metadata
        meta = _get_metadata_for(instance_name)
        cached_creation_date = meta.get('cachedCreationDate', '')
        cached_snapshot = meta.get('sourceSnapshot', '')
        cached_source_inst = meta.get('sourceInstance', '')

        # Decide: use cached snapshot info, or re-fetch from events?
        if cached_snapshot and cached_creation_date == current_creation_date:
            # FAST PATH: cache is valid and matches current state
            source_snapshot = cached_snapshot
            source_instance = cached_source_inst
        else:
            # SLOW PATH: cache missing or DB was restored — fetch fresh
            restore_info = _get_restore_info_from_events(rds, instance_name)
            fresh_snapshot = restore_info['sourceSnapshot']
            fresh_source_inst = restore_info['sourceInstance']

            if fresh_snapshot:
                # Got fresh data → use it AND update the cache
                source_snapshot = fresh_snapshot
                source_instance = fresh_source_inst

                # Persist to DynamoDB for next time (merge with existing user metadata)
                updated_meta = dict(meta)  # Preserve user fields
                updated_meta['sourceSnapshot'] = fresh_snapshot
                updated_meta['sourceInstance'] = fresh_source_inst
                updated_meta['cachedCreationDate'] = current_creation_date
                _save_metadata(instance_name, updated_meta)
            else:
                # Events returned nothing (aged out or never restored)
                # Keep using the old cached value rather than blanking it out
                source_snapshot = cached_snapshot
                source_instance = cached_source_inst

        # Fallback for source instance: if events didn't have it, try replica source
        if not source_instance:
            source_instance = db.get('ReadReplicaSourceDBInstanceIdentifier', '')

        return {
            'databaseName': db.get('DBName', ''),
            'instanceName': db.get('DBInstanceIdentifier', ''),
            'status': db.get('DBInstanceStatus', ''),
            'endpoint': endpoint.get('Address', ''),
            'creationDate': current_creation_date,
            'sourceSnapshot': source_snapshot,
            'sourceInstance': source_instance,
            'latestRestorableTime': _format_date(db.get('LatestRestorableTime')),
            'databaseVersion': db.get('EngineVersion', ''),
            'applicationVersion': meta.get('applicationVersion', ''),
            'lastUpgradeDate': meta.get('lastUpgradeDate', ''),
            'owner': meta.get('owner', ''),
            'functionality': meta.get('functionality', '')
        }

    except rds.exceptions.DBInstanceNotFoundFault:
        return None
    except ClientError as e:
        print(f"Error fetching {instance_name}: {e}")
        return None


# ROUTES

def list_databases():
    """
    Fetches RDS instances from all accounts AND metadata from DynamoDB,
    all in parallel for maximum speed.
    """
    all_databases = []

    # Resolve account list first (cheap, just STS + IAM calls)
    accounts = list(_iterate_accounts())

    # Run all fetches in parallel: each account + DynamoDB scan
    with ThreadPoolExecutor(max_workers=len(accounts) + 1) as executor:
        # Submit DynamoDB scan
        metadata_future = executor.submit(_get_all_metadata)

        # Submit each account's RDS fetch
        account_futures = {
            executor.submit(
                _fetch_databases_no_metadata,
                acc['session'],
                acc['account_id'],
                acc['environment']
            ): acc for acc in accounts
        }

        # Wait for metadata
        metadata_lookup = metadata_future.result()

        # Collect account results as they complete
        for future in as_completed(account_futures):
            acc = account_futures[future]
            try:
                dbs = future.result()
                # Merge metadata into each db
                for db in dbs:
                    meta = metadata_lookup.get(db['instanceName'], {})
                    db['owner'] = meta.get('owner', '')
                    db['functionality'] = meta.get('functionality', '')
                    db['appVersion'] = meta.get('applicationVersion', '')
                    db['lastUpgrade'] = meta.get('lastUpgradeDate', '')
                    db['sourceInstance'] = meta.get('sourceInstance', '')

                all_databases.extend(dbs)
            except Exception as e:
                print(f"Error fetching from {acc['account_id']}: {e}")

    all_databases.sort(key=lambda d: (
        0 if d['environment'] == 'Production' else 1,
        d.get('databaseName') or ''
    ))

    return _response(200, {'databases': all_databases})


def get_database_detail(instance_name):
    if not instance_name:
        return _response(400, {'error': 'instanceName is required'})

    for acc in _iterate_accounts():
        db = _fetch_single_db(acc['session'], instance_name)
        if db:
            db['environment'] = acc['environment']
            db['accountId'] = acc['account_id']
            return _response(200, {'database': db})

    return _response(404, {'error': 'Database not found'})


def update_metadata(instance_name, body):
    if not instance_name:
        return _response(400, {'error': 'instanceName is required'})

    try:
        body = json.loads(body or '{}') if isinstance(body, str) else (body or {})

        if not isinstance(body, dict):
            return _response(400, {'error': 'Invalid JSON body'})

        saved_item = _save_metadata(instance_name, body)

        return _response(200, {
            'message': 'Metadata saved successfully',
            'data': saved_item
        })

    except json.JSONDecodeError:
        return _response(400, {'error': 'Invalid JSON'})
    except ClientError as e:
        print(f"DynamoDB error: {e}")
        return _response(500, {'error': 'Failed to save metadata'})


# HELPERS

def _get_origin_verify_secret():
    """
    Fetches the origin-verify secret from Secrets Manager, with a 5-minute cache.
    Returns '' if not configured or on error (fails closed via the handler check).
    """
    if not ORIGIN_VERIFY_SECRET_ARN:
        return ''

    now = time.time()
    cached = _origin_secret_cache['value']
    if cached is not None and (now - _origin_secret_cache['fetched_at']) < ORIGIN_SECRET_CACHE_TTL:
        return cached

    try:
        response = secrets_client.get_secret_value(SecretId=ORIGIN_VERIFY_SECRET_ARN)
        secret_string = response.get('SecretString', '{}')
        secret_dict = json.loads(secret_string)
        secret_value = secret_dict.get('originVerifySecret', '')

        _origin_secret_cache['value'] = secret_value
        _origin_secret_cache['fetched_at'] = now
        return secret_value

    except ClientError as e:
        print(f"Error fetching origin-verify secret: {e}")
        # Fall back to last cached value if we have one (avoids outage on transient errors)
        return cached if cached is not None else ''
    except (json.JSONDecodeError, KeyError) as e:
        print(f"Error parsing origin-verify secret: {e}")
        return cached if cached is not None else ''


def _response(status_code, body):
    return {
        'statusCode': status_code,
        'headers': {
            'Content-Type': 'application/json'
        },
        'body': json.dumps(body, default=str)
    }


def _format_date(dt):
    return dt.strftime('%d/%m/%Y %H:%M:%S') if dt else ''