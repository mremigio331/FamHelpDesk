import {
  Stack,
  Duration,
  aws_cloudwatch as cloudwatch,
  aws_apigateway as apigw,
  aws_sns as sns,
  aws_sns_subscriptions as subs,
} from "aws-cdk-lib";
import * as cloudwatch_actions from "aws-cdk-lib/aws-cloudwatch-actions";
import { famHelpDesk } from "../constants";

export interface ApiMetrics {
  api2xxMetric: cloudwatch.Metric;
  api4xxMetric: cloudwatch.Metric;
  api5xxMetric: cloudwatch.Metric;
  alarm2xx: cloudwatch.Alarm;
  alarm4xx: cloudwatch.Alarm;
  alarm5xx: cloudwatch.Alarm;
}

export function addApiMonitoring(
  scope: Stack,
  api: apigw.LambdaRestApi,
  stage: string,
  escalationEmail: string,
  escalationNumber: string,
): ApiMetrics {
  const apiGatewayName = `${famHelpDesk}-Api-${stage}`;
  const apiStageName = api.deploymentStage.stageName;

  // Create SNS Topic for alarm notifications
  const alarmTopic = new sns.Topic(
    scope,
    `${famHelpDesk}-ApiAlarmTopic-${stage}`,
    {
      topicName: `${famHelpDesk}-ApiAlarmTopic-${stage}`,
      displayName: `${famHelpDesk} API Alarm Topic (${stage})`,
    },
  );

  // Add email and SMS subscriptions
  alarmTopic.addSubscription(new subs.EmailSubscription(escalationEmail));
  alarmTopic.addSubscription(new subs.SmsSubscription(escalationNumber));

  const api2xxMetric = new cloudwatch.Metric({
    namespace: "AWS/ApiGateway",
    metricName: "2XXSuccess",
    dimensionsMap: {
      ApiName: apiGatewayName,
      Stage: apiStageName,
    },
    statistic: "Sum",
    period: Duration.minutes(5),
  });

  // 4XX metric
  const api4xxMetric = new cloudwatch.Metric({
    namespace: "AWS/ApiGateway",
    metricName: "4XXError",
    dimensionsMap: {
      ApiName: apiGatewayName,
      Stage: apiStageName,
    },
    statistic: "Sum",
    period: Duration.minutes(5),
  });

  // Count metric (total requests)
  const apiCountMetric = new cloudwatch.Metric({
    namespace: "AWS/ApiGateway",
    metricName: "Count",
    dimensionsMap: {
      ApiName: apiGatewayName,
      Stage: apiStageName,
    },
    statistic: "Sum",
    period: Duration.minutes(5),
  });

  // Math expression for 4XX error rate (%)
  const api4xxRate = new cloudwatch.MathExpression({
    expression: "100 * (fourxx / total)",
    usingMetrics: {
      fourxx: api4xxMetric,
      total: apiCountMetric,
    },
    label: "4XX Error Rate (%)",
    period: Duration.minutes(5),
  });

  // 5XX metric
  const api5xxMetric = new cloudwatch.Metric({
    namespace: "AWS/ApiGateway",
    metricName: "5XXError",
    dimensionsMap: {
      ApiName: apiGatewayName,
      Stage: apiStageName,
    },
    statistic: "Sum",
    period: Duration.minutes(5),
  });

  // === Alarm for 2XX success rate (monitor for low success) ===
  const alarm2xx = new cloudwatch.Alarm(
    scope,
    `${famHelpDesk}-Api-2XXAlarm-${stage}`,
    {
      alarmName: `${famHelpDesk}-Api-2XXAlarm-${stage}`,
      metric: api2xxMetric,
      threshold: 10, // Alert if less than 10 successful requests in 5 minutes (adjust as needed)
      evaluationPeriods: 2,
      datapointsToAlarm: 2,
      treatMissingData: cloudwatch.TreatMissingData.NOT_BREACHING,
      alarmDescription: `${famHelpDesk}-Api-2XXAlarm-${stage}: Monitor for low 2XX success rate on API Gateway (${stage})`,
      comparisonOperator: cloudwatch.ComparisonOperator.LESS_THAN_THRESHOLD,
      actionsEnabled: false, // No actions, just for monitoring
    },
  );

  // === Alarm for 4XX error rate ===
  const alarm4xx = new cloudwatch.Alarm(
    scope,
    `${famHelpDesk}-Api-4XXAlarm-${stage}`,
    {
      alarmName: `${famHelpDesk}-Api-4XXAlarm-${stage}`,
      metric: api4xxMetric,
      threshold: 5, // Alert if more than 5 4XX errors in 5 minutes
      evaluationPeriods: 1,
      datapointsToAlarm: 1,
      treatMissingData: cloudwatch.TreatMissingData.NOT_BREACHING,
      alarmDescription: `${famHelpDesk}-Api-4XXAlarm-${stage}: Monitor for high 4XX error rate on API Gateway (${stage})`,
      comparisonOperator: cloudwatch.ComparisonOperator.GREATER_THAN_THRESHOLD,
      actionsEnabled: false, // No actions, just for monitoring
    },
  );

  // === Alarm for 5XX errors ===
  const alarm5xx = new cloudwatch.Alarm(
    scope,
    `${famHelpDesk}-Api-5XXAlarm-${stage}`,
    {
      alarmName: `${famHelpDesk}-Api-5XXAlarm-${stage}`,
      metric: api5xxMetric,
      threshold: 1,
      evaluationPeriods: 1,
      datapointsToAlarm: 1,
      treatMissingData: cloudwatch.TreatMissingData.NOT_BREACHING,
      alarmDescription: `${famHelpDesk}-Api-5XXAlarm-${stage}: Alarm if any 5XX errors occur on API Gateway (${stage})`,
      comparisonOperator:
        cloudwatch.ComparisonOperator.GREATER_THAN_OR_EQUAL_TO_THRESHOLD,
      actionsEnabled: true,
    },
  );
  alarm5xx.addAlarmAction(new cloudwatch_actions.SnsAction(alarmTopic));
  alarm5xx.addOkAction(new cloudwatch_actions.SnsAction(alarmTopic));

  return {
    api2xxMetric,
    api4xxMetric,
    api5xxMetric,
    alarm2xx,
    alarm4xx,
    alarm5xx,
  };
}
