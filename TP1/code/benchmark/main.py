from datetime import datetime, timedelta
import os
import boto3
from matplotlib import pyplot
from datetime import timedelta, datetime

AWS_ACCESS_KEY = os.environ.get('AWS_ACCESS_KEY')
AWS_SECRET_ACCESS_KEY = os.environ.get('AWS_SECRET_ACCESS_KEY')
AWS_SESSION_TOKEN = os.environ.get('AWS_SESSION_TOKEN')


def create_client(service_name, region="us-east-1", access_key=None, secret_key=None, session_token=None):
    return boto3.client(
        service_name,
        region_name=region,
        aws_access_key_id=access_key,
        aws_secret_access_key=secret_key,
        aws_session_token=session_token
    )


def initialize_clients():
    common_args = {
        "region": "us-east-1",
        "access_key": AWS_ACCESS_KEY,
        "secret_key": AWS_SECRET_ACCESS_KEY,
        "session_token": AWS_SESSION_TOKEN
    }

    elbv2_client = create_client("elbv2", **common_args)
    cloudwatch = create_client("cloudwatch", **common_args)

    return elbv2_client, cloudwatch


def get_elb_info(elbv2_client):
    try:
        load_balancers_data = elbv2_client.describe_load_balancers()

        if not load_balancers_data.get('LoadBalancers'):
            raise ValueError("No Load Balancers found.")

        load_balancer_arn = load_balancers_data['LoadBalancers'][0].get(
            'LoadBalancerArn', '')

        arn_components = load_balancer_arn.split(':')[-1].split('/')
        elbv2_info = '/'.join(arn_components[1:4])

        return elbv2_info

    except Exception as e:
        print(f"Error getting ELB info: {e}")
        return None


def get_clusters(elbv2_client):
    try:
        target_groups = elbv2_client.describe_target_groups().get('TargetGroups', [])

        if len(target_groups) < 2:
            raise ValueError(
                "Expected at least 2 target groups but found fewer.")

        target_group_m4_arn = target_groups[0].get('TargetGroupArn', '')
        target_group_t2_arn = target_groups[1].get('TargetGroupArn', '')

        target_group_m4 = target_group_m4_arn.split(':')[-1]
        target_group_t2 = target_group_t2_arn.split(':')[-1]

        return target_group_m4, target_group_t2

    except Exception as e:
        print(f"Error getting clusters: {e}")
        return None, None


def construct_metric_query(metric_name, clusters, elbv2_info, stat):
    metric_query = {
        'Id': 'myrequest',
        'MetricStat': {
            'Metric': {
                'Namespace': 'AWS/ApplicationELB',
                'MetricName': metric_name,
                'Dimensions': []
            },
            'Period': 300,
            'Stat': stat,
        }
    }

    if clusters:
        metric_query['MetricStat']['Metric']['Dimensions'].append(
            {'Name': 'TargetGroup', 'Value': clusters})

    if elbv2_info:
        metric_query['MetricStat']['Metric']['Dimensions'].append(
            {'Name': 'LoadBalancer', 'Value': elbv2_info})

    return metric_query


def get_metric(cloudwatch, elbv2_info, clusters, metric_name, stat, get_value):
    metric_query = construct_metric_query(
        metric_name, clusters, elbv2_info, stat)

    response = cloudwatch.get_metric_data(
        MetricDataQueries=[metric_query],
        StartTime=datetime.utcnow() - timedelta(days=1),
        EndTime=datetime.utcnow() + timedelta(days=1)
    )

    if get_value:
        return response.get('MetricDataResults', [{}])[0].get('Values', [])
    return response


def get_clusters_metrics(cloudwatch, elbv2_info, metric_name, stat):
    return get_metric(cloudwatch, elbv2_info, None, metric_name, stat, True)


def build_clusters(cloudwatch, elbv2_info, cluster_m4, cluster_t2):

    pyplot.bar(['M4', 'T2'], [sum(get_metric(cloudwatch, elbv2_info, cluster_m4, 'RequestCount', 'Sum', True)), sum(
        get_metric(cloudwatch, elbv2_info, cluster_t2, 'RequestCount', 'Sum', True))], color=['blue', 'red'])

    pyplot.title('Number of Requests per Cluster')
    pyplot.savefig('metrics/clusters_requests.png', bbox_inches='tight')

    m4_response_time = get_metric(cloudwatch, elbv2_info, cluster_m4,
                                  'TargetResponseTime', 'Average', True)
    t2_response_time = get_metric(cloudwatch, elbv2_info, cluster_t2,
                                  'TargetResponseTime', 'Average', True)

    average_m4_time = sum(m4_response_time) / \
        len(m4_response_time) if len(m4_response_time) > 0 else 0
    average_t2_time = sum(t2_response_time) / \
        len(t2_response_time) if len(t2_response_time) > 0 else 0

    pyplot.bar(['M4', 'T2'], [average_m4_time, average_t2_time],
               color=['blue', 'red'])
    pyplot.title('Average Response Time per Cluster')
    pyplot.savefig('metrics/clusters_average_response_time.png')


def fetch_data(cloudwatch_client, elb_name, metric_name, stat, cluster=None):
    if cluster:
        data = get_metric(cloudwatch_client, elb_name,
                          cluster, metric_name, stat, True)
        return max(data)
    else:
        data = get_clusters_metrics(
            cloudwatch_client, elb_name, metric_name, stat)
        if metric_name == 'ActiveConnectionCount':
            return sum(data)/len(data) if data else 0
        else:
            return sum(data)


def build_table(cloudwatch_client, elb_name, cluster_m4, cluster_t2):
    average_connections = fetch_data(cloudwatch_client, elb_name,
                                     'ActiveConnectionCount', 'Sum')
    total_bytes = fetch_data(cloudwatch_client, elb_name,
                             'ProcessedBytes', 'Sum')
    number_requests = fetch_data(
        cloudwatch_client, elb_name, 'RequestCount', 'Sum')
    number_m4 = fetch_data(cloudwatch_client, elb_name,
                           'HealthyHostCount', 'Maximum', cluster_m4)
    number_t2 = fetch_data(cloudwatch_client, elb_name,
                           'HealthyHostCount', 'Maximum', cluster_t2)

    data = [
        ["Total number of requests", number_requests],
        ["Total bytes processed", total_bytes],
        ["Average number of connections", average_connections],
        ["Number of healthy instances M4", number_m4],
        ['Number of healthy instances T2', number_t2]
    ]

    plot_table_data(data)


def plot_table_data(data):
    ax = pyplot.subplots()
    table = ax.table(cellText=data, loc='center')
    table.set_fontsize(12)
    ax.text(0.5, 0.65, 'Load Balancer Metrics', size=10, ha='center',
            transform=ax.transAxes)
    ax.axis('off')
    pyplot.savefig('metrics/load_balancer_metrics.png', bbox_inches='tight')


def main():
    elbv2_client, cloudwatch = initialize_clients()
    elbv2_info = get_elb_info(elbv2_client)
    cluster_m4, cluster_t2 = get_clusters(elbv2_client)

    build_table(cloudwatch, elbv2_info, cluster_m4, cluster_t2)
    build_clusters(cloudwatch, elbv2_info,
                   cluster_m4, cluster_t2)


if __name__ == '__main__':
    main()
