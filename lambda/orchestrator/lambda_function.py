"""
Lambda Orchestrator for Glue Streaming Job
Controls the start/stop of the Glue streaming job based on EventBridge triggers
"""

import json
import os
from datetime import datetime
import boto3
from botocore.exceptions import ClientError

# Initialize AWS clients
glue_client = boto3.client('glue')
cloudwatch = boto3.client('cloudwatch')

# Environment variables
GLUE_JOB_NAME = os.environ.get('GLUE_JOB_NAME', 'ecommerce-stream-processor')
GLUE_JOB_TIMEOUT = int(os.environ.get('GLUE_JOB_TIMEOUT', '60'))  # minutes


def publish_metric(metric_name, value, unit='Count'):
    """Publish custom CloudWatch metric"""
    try:
        cloudwatch.put_metric_data(
            Namespace='EcommerceStreaming',
            MetricData=[
                {
                    'MetricName': metric_name,
                    'Value': value,
                    'Unit': unit,
                    'Timestamp': datetime.utcnow()
                }
            ]
        )
    except Exception as e:
        print(f"Error publishing metric: {str(e)}")


def start_glue_job():
    """Start the Glue streaming job"""
    try:
        response = glue_client.start_job_run(
            JobName=GLUE_JOB_NAME,
            Arguments={
                '--job-bookmark-option': 'job-bookmark-disable',
                '--TempDir': f's3://ecommerce-streaming-scripts/temp/',
                '--enable-metrics': 'true',
                '--enable-continuous-cloudwatch-log': 'true',
                '--enable-spark-ui': 'true',
                '--spark-event-logs-path': 's3://ecommerce-streaming-scripts/spark-logs/'
            },
            Timeout=GLUE_JOB_TIMEOUT,
            MaxCapacity=2.0  # 2 DPU for streaming job
        )
        
        job_run_id = response['JobRunId']
        
        print(f"Glue job started successfully. JobRunId: {job_run_id}")
        publish_metric('GlueJobStarted', 1)
        
        return {
            'status': 'started',
            'job_run_id': job_run_id,
            'job_name': GLUE_JOB_NAME
        }
        
    except ClientError as e:
        error_code = e.response['Error']['Code']
        
        if error_code == 'ConcurrentRunsExceededException':
            print(f"Job {GLUE_JOB_NAME} is already running")
            return {
                'status': 'already_running',
                'message': 'Job is already running'
            }
        else:
            print(f"Error starting Glue job: {str(e)}")
            publish_metric('GlueJobStartError', 1)
            raise
            
    except Exception as e:
        print(f"Unexpected error starting Glue job: {str(e)}")
        publish_metric('GlueJobStartError', 1)
        raise


def stop_glue_job():
    """Stop the currently running Glue job"""
    try:
        # Get list of running jobs
        response = glue_client.get_job_runs(
            JobName=GLUE_JOB_NAME,
            MaxResults=10
        )
        
        stopped_runs = []
        
        for job_run in response['JobRuns']:
            if job_run['JobRunState'] in ['RUNNING', 'STARTING']:
                job_run_id = job_run['Id']
                
                # Stop the job run
                glue_client.batch_stop_job_run(
                    JobName=GLUE_JOB_NAME,
                    JobRunIds=[job_run_id]
                )
                
                stopped_runs.append(job_run_id)
                print(f"Stopped job run: {job_run_id}")
        
        if stopped_runs:
            publish_metric('GlueJobStopped', len(stopped_runs))
            return {
                'status': 'stopped',
                'job_runs_stopped': stopped_runs,
                'count': len(stopped_runs)
            }
        else:
            print("No running jobs found to stop")
            return {
                'status': 'no_running_jobs',
                'message': 'No active jobs to stop'
            }
            
    except Exception as e:
        print(f"Error stopping Glue job: {str(e)}")
        publish_metric('GlueJobStopError', 1)
        raise


def get_job_status():
    """Get the current status of the Glue job"""
    try:
        response = glue_client.get_job_runs(
            JobName=GLUE_JOB_NAME,
            MaxResults=5
        )
        
        job_runs = []
        for run in response['JobRuns']:
            job_runs.append({
                'job_run_id': run['Id'],
                'state': run['JobRunState'],
                'started_on': run.get('StartedOn').isoformat() if run.get('StartedOn') else None,
                'completed_on': run.get('CompletedOn').isoformat() if run.get('CompletedOn') else None,
                'execution_time': run.get('ExecutionTime', 0)
            })
        
        return {
            'status': 'retrieved',
            'job_name': GLUE_JOB_NAME,
            'recent_runs': job_runs
        }
        
    except Exception as e:
        print(f"Error getting job status: {str(e)}")
        raise


def lambda_handler(event, context):
    """
    Main Lambda handler
    Handles start, stop, and status check actions for Glue streaming job
    """
    try:
        print(f"Event received: {json.dumps(event)}")
        
        # Determine action from event
        action = event.get('action', 'start')
        
        # EventBridge events have different structure
        if 'detail-type' in event:
            action = event.get('detail', {}).get('action', 'start')
        
        print(f"Action requested: {action}")
        
        # Execute action
        if action == 'start':
            result = start_glue_job()
        elif action == 'stop':
            result = stop_glue_job()
        elif action == 'status':
            result = get_job_status()
        else:
            raise ValueError(f"Invalid action: {action}. Must be 'start', 'stop', or 'status'")
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': f'Action {action} completed successfully',
                'result': result,
                'timestamp': datetime.utcnow().isoformat()
            })
        }
        
    except Exception as e:
        print(f"Lambda execution error: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'message': 'Error in orchestration',
                'error': str(e),
                'timestamp': datetime.utcnow().isoformat()
            })
        }
