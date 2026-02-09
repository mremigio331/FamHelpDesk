import {
  Stack,
  Duration,
  aws_cloudwatch as cloudwatch,
  aws_sns as sns,
  aws_sqs as sqs,
  aws_lambda as lambda,
  aws_sns_subscriptions as subs,
} from "aws-cdk-lib";
import * as cloudwatchActions from "aws-cdk-lib/aws-cloudwatch-actions";
import { famHelpDesk } from "../constants";

export interface NotificationMetrics {
  dlqMessageCountMetric: cloudwatch.Metric;
  dlqAlarm: cloudwatch.Alarm;
  lambdaErrorMetric: cloudwatch.Metric;
  lambdaInvocationsMetric: cloudwatch.Metric;
  lambdaErrorAlarm: cloudwatch.Alarm;
  lambdaInvocationsAlarm: cloudwatch.Alarm;
  alarmTopic: sns.Topic;
  // Push notification metrics
  pushNotificationsSentMetric: cloudwatch.Metric;
  pushNotificationsFailedMetric: cloudwatch.Metric;
  devicesDisabledMetric: cloudwatch.Metric;
  pushNotificationFailureRateAlarm: cloudwatch.Alarm;
  devicesDisabledAlarm: cloudwatch.Alarm;
}

export function addNotificationMonitoring(
  scope: Stack,
  stage: string,
  deadLetterQueue: sqs.Queue,
  notificationProcessor: lambda.Function,
  escalationEmail: string,
  escalationNumber: string,
): NotificationMetrics {
  // Create SNS Topic for alarm notifications
  const alarmTopic = new sns.Topic(scope, `${famHelpDesk}-NotificationAlarmTopic-${stage}`, {
    topicName: `${famHelpDesk}-NotificationAlarmTopic-${stage}`,
    displayName: `${famHelpDesk} Notification Alarm Topic (${stage})`,
  });

  // Add email and SMS subscriptions for alerts
  alarmTopic.addSubscription(new subs.EmailSubscription(escalationEmail));
  alarmTopic.addSubscription(new subs.SmsSubscription(escalationNumber));

  // Create CloudWatch metric for DLQ message count
  const dlqMessageCountMetric = new cloudwatch.Metric({
    namespace: "AWS/SQS",
    metricName: "ApproximateNumberOfVisibleMessages",
    dimensionsMap: {
      QueueName: deadLetterQueue.queueName,
    },
    statistic: "Maximum",
    period: Duration.minutes(1),
  });

  // Create alarm for DLQ messages > 1
  const dlqAlarm = new cloudwatch.Alarm(scope, `${famHelpDesk}-NotificationDLQAlarm-${stage}`, {
    alarmName: `${famHelpDesk}-NotificationDLQAlarm-${stage}`,
    metric: dlqMessageCountMetric,
    threshold: 1,
    evaluationPeriods: 1,
    datapointsToAlarm: 1,
    treatMissingData: cloudwatch.TreatMissingData.NOT_BREACHING,
    alarmDescription: `${famHelpDesk} Notification DLQ Alarm (${stage}): Alert when DLQ has more than 1 visible message`,
    comparisonOperator: cloudwatch.ComparisonOperator.GREATER_THAN_THRESHOLD,
    actionsEnabled: true,
  });

  // Add alarm actions
  dlqAlarm.addAlarmAction(new cloudwatchActions.SnsAction(alarmTopic));
  dlqAlarm.addOkAction(new cloudwatchActions.SnsAction(alarmTopic));

  // Create Lambda error rate alarm
  const lambdaErrorMetric = new cloudwatch.Metric({
    namespace: "AWS/Lambda",
    metricName: "Errors",
    dimensionsMap: {
      FunctionName: notificationProcessor.functionName,
    },
    statistic: "Sum",
    period: Duration.minutes(5),
  });

  // Create Lambda invocations metric
  const lambdaInvocationsMetric = new cloudwatch.Metric({
    namespace: "AWS/Lambda",
    metricName: "Invocations",
    dimensionsMap: {
      FunctionName: notificationProcessor.functionName,
    },
    statistic: "Sum",
    period: Duration.minutes(5),
  });

  const lambdaErrorAlarm = new cloudwatch.Alarm(scope, `${famHelpDesk}-NotificationLambdaErrorAlarm-${stage}`, {
    alarmName: `${famHelpDesk}-NotificationLambdaErrorAlarm-${stage}`,
    metric: lambdaErrorMetric,
    threshold: 1,
    evaluationPeriods: 1,
    datapointsToAlarm: 1,
    treatMissingData: cloudwatch.TreatMissingData.NOT_BREACHING,
    alarmDescription: `${famHelpDesk} Notification Lambda Error Alarm (${stage}): Alert when notification processor Lambda has errors`,
    comparisonOperator: cloudwatch.ComparisonOperator.GREATER_THAN_OR_EQUAL_TO_THRESHOLD,
    actionsEnabled: true,
  });

  lambdaErrorAlarm.addAlarmAction(new cloudwatchActions.SnsAction(alarmTopic));
  lambdaErrorAlarm.addOkAction(new cloudwatchActions.SnsAction(alarmTopic));

  // Create alarm for invocations (monitor for unusual activity)
  const lambdaInvocationsAlarm = new cloudwatch.Alarm(scope, `${famHelpDesk}-NotificationLambdaInvocationsAlarm-${stage}`, {
    alarmName: `${famHelpDesk}-NotificationLambdaInvocationsAlarm-${stage}`,
    metric: lambdaInvocationsMetric,
    threshold: 100, // Alert if more than 100 invocations in 5 minutes (adjust as needed)
    evaluationPeriods: 1,
    datapointsToAlarm: 1,
    treatMissingData: cloudwatch.TreatMissingData.NOT_BREACHING,
    alarmDescription: `${famHelpDesk} Notification Lambda Invocations Alarm (${stage}): Monitor for high notification processor activity`,
    comparisonOperator: cloudwatch.ComparisonOperator.GREATER_THAN_THRESHOLD,
    actionsEnabled: false, // No actions, just for monitoring
  });

  // Create custom metrics for push notifications
  const pushNotificationsSentMetric = new cloudwatch.Metric({
    namespace: `${famHelpDesk}/Notifications`,
    metricName: "PushNotificationsSent",
    dimensionsMap: {
      Stage: stage,
    },
    statistic: "Sum",
    period: Duration.minutes(5),
  });

  const pushNotificationsFailedMetric = new cloudwatch.Metric({
    namespace: `${famHelpDesk}/Notifications`,
    metricName: "PushNotificationsFailed",
    dimensionsMap: {
      Stage: stage,
    },
    statistic: "Sum",
    period: Duration.minutes(5),
  });

  const devicesDisabledMetric = new cloudwatch.Metric({
    namespace: `${famHelpDesk}/Notifications`,
    metricName: "DevicesDisabled",
    dimensionsMap: {
      Stage: stage,
    },
    statistic: "Sum",
    period: Duration.minutes(5),
  });

  // Create alarm for high push notification failure rate
  // This uses a math expression to calculate failure rate: failed / (sent + failed)
  const pushNotificationFailureRateAlarm = new cloudwatch.Alarm(
    scope,
    `${famHelpDesk}-PushNotificationFailureRateAlarm-${stage}`,
    {
      alarmName: `${famHelpDesk}-PushNotificationFailureRateAlarm-${stage}`,
      metric: new cloudwatch.MathExpression({
        expression: "IF(sent + failed > 0, failed / (sent + failed) * 100, 0)",
        usingMetrics: {
          sent: pushNotificationsSentMetric,
          failed: pushNotificationsFailedMetric,
        },
        period: Duration.minutes(5),
      }),
      threshold: 50, // Alert if failure rate > 50%
      evaluationPeriods: 2,
      datapointsToAlarm: 2,
      treatMissingData: cloudwatch.TreatMissingData.NOT_BREACHING,
      alarmDescription: `${famHelpDesk} Push Notification Failure Rate Alarm (${stage}): Alert when push notification failure rate exceeds 50%`,
      comparisonOperator: cloudwatch.ComparisonOperator.GREATER_THAN_THRESHOLD,
      actionsEnabled: true,
    }
  );

  pushNotificationFailureRateAlarm.addAlarmAction(new cloudwatchActions.SnsAction(alarmTopic));
  pushNotificationFailureRateAlarm.addOkAction(new cloudwatchActions.SnsAction(alarmTopic));

  // Create alarm for high device disablement rate
  const devicesDisabledAlarm = new cloudwatch.Alarm(
    scope,
    `${famHelpDesk}-DevicesDisabledAlarm-${stage}`,
    {
      alarmName: `${famHelpDesk}-DevicesDisabledAlarm-${stage}`,
      metric: devicesDisabledMetric,
      threshold: 10, // Alert if more than 10 devices disabled in 5 minutes
      evaluationPeriods: 1,
      datapointsToAlarm: 1,
      treatMissingData: cloudwatch.TreatMissingData.NOT_BREACHING,
      alarmDescription: `${famHelpDesk} Devices Disabled Alarm (${stage}): Alert when more than 10 devices are disabled in 5 minutes`,
      comparisonOperator: cloudwatch.ComparisonOperator.GREATER_THAN_THRESHOLD,
      actionsEnabled: true,
    }
  );

  devicesDisabledAlarm.addAlarmAction(new cloudwatchActions.SnsAction(alarmTopic));
  devicesDisabledAlarm.addOkAction(new cloudwatchActions.SnsAction(alarmTopic));

  return {
    dlqMessageCountMetric,
    dlqAlarm,
    lambdaErrorMetric,
    lambdaInvocationsMetric,
    lambdaErrorAlarm,
    lambdaInvocationsAlarm,
    alarmTopic,
    pushNotificationsSentMetric,
    pushNotificationsFailedMetric,
    devicesDisabledMetric,
    pushNotificationFailureRateAlarm,
    devicesDisabledAlarm,
  };
}