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
  iosPushDlqMessageCountMetric: cloudwatch.Metric;
  iosPushDlqAlarm: cloudwatch.Alarm;
  lambdaErrorMetric: cloudwatch.Metric;
  lambdaInvocationsMetric: cloudwatch.Metric;
  lambdaErrorAlarm: cloudwatch.Alarm;
  lambdaInvocationsAlarm: cloudwatch.Alarm;
  alarmTopic: sns.Topic;
  // Push notification metrics
  pushNotificationsSentMetric: cloudwatch.Metric;
  pushNotificationsFailedMetric: cloudwatch.Metric;
  devicesDisabledMetric: cloudwatch.Metric;
  apnsRateLimitErrorsMetric: cloudwatch.Metric;
  apnsServerErrorsMetric: cloudwatch.Metric;
  pushNotificationFailureRateAlarm: cloudwatch.Alarm;
  devicesDisabledAlarm: cloudwatch.Alarm;
  apnsRateLimitAlarm: cloudwatch.Alarm;
  apnsServerErrorAlarm: cloudwatch.Alarm;
  dashboard: cloudwatch.Dashboard;
}

export function addNotificationMonitoring(
  scope: Stack,
  stage: string,
  deadLetterQueue: sqs.Queue,
  iosPushDeadLetterQueue: sqs.Queue,
  notificationProcessor: lambda.Function,
  escalationEmail: string,
  escalationNumber: string,
): NotificationMetrics {
  // Create SNS Topic for alarm notifications
  const alarmTopic = new sns.Topic(
    scope,
    `${famHelpDesk}-NotificationAlarmTopic-${stage}`,
    {
      topicName: `${famHelpDesk}-NotificationAlarmTopic-${stage}`,
      displayName: `${famHelpDesk} Notification Alarm Topic (${stage})`,
    },
  );

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
  const dlqAlarm = new cloudwatch.Alarm(
    scope,
    `${famHelpDesk}-NotificationDLQAlarm-${stage}`,
    {
      alarmName: `${famHelpDesk}-NotificationDLQAlarm-${stage}`,
      metric: dlqMessageCountMetric,
      threshold: 0,
      evaluationPeriods: 1,
      datapointsToAlarm: 1,
      treatMissingData: cloudwatch.TreatMissingData.NOT_BREACHING,
      alarmDescription: `${famHelpDesk} Notification DLQ Alarm (${stage}): Alert when DLQ has any visible messages`,
      comparisonOperator: cloudwatch.ComparisonOperator.GREATER_THAN_THRESHOLD,
      actionsEnabled: true,
    },
  );

  // Add alarm actions
  dlqAlarm.addAlarmAction(new cloudwatchActions.SnsAction(alarmTopic));
  dlqAlarm.addOkAction(new cloudwatchActions.SnsAction(alarmTopic));

  // Create CloudWatch metric for iOS Push DLQ message count
  const iosPushDlqMessageCountMetric = new cloudwatch.Metric({
    namespace: "AWS/SQS",
    metricName: "ApproximateNumberOfVisibleMessages",
    dimensionsMap: {
      QueueName: iosPushDeadLetterQueue.queueName,
    },
    statistic: "Maximum",
    period: Duration.minutes(1),
  });

  // Create alarm for iOS Push DLQ messages > 0
  const iosPushDlqAlarm = new cloudwatch.Alarm(
    scope,
    `${famHelpDesk}-IosPushDLQAlarm-${stage}`,
    {
      alarmName: `${famHelpDesk}-IosPushDLQAlarm-${stage}`,
      metric: iosPushDlqMessageCountMetric,
      threshold: 0,
      evaluationPeriods: 1,
      datapointsToAlarm: 1,
      treatMissingData: cloudwatch.TreatMissingData.NOT_BREACHING,
      alarmDescription: `${famHelpDesk} iOS Push DLQ Alarm (${stage}): Alert when iOS Push DLQ has any visible messages`,
      comparisonOperator: cloudwatch.ComparisonOperator.GREATER_THAN_THRESHOLD,
      actionsEnabled: true,
    },
  );

  // Add alarm actions for iOS Push DLQ
  iosPushDlqAlarm.addAlarmAction(new cloudwatchActions.SnsAction(alarmTopic));
  iosPushDlqAlarm.addOkAction(new cloudwatchActions.SnsAction(alarmTopic));

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

  const lambdaErrorAlarm = new cloudwatch.Alarm(
    scope,
    `${famHelpDesk}-NotificationLambdaErrorAlarm-${stage}`,
    {
      alarmName: `${famHelpDesk}-NotificationLambdaErrorAlarm-${stage}`,
      metric: lambdaErrorMetric,
      threshold: 1,
      evaluationPeriods: 1,
      datapointsToAlarm: 1,
      treatMissingData: cloudwatch.TreatMissingData.NOT_BREACHING,
      alarmDescription: `${famHelpDesk} Notification Lambda Error Alarm (${stage}): Alert when notification processor Lambda has errors`,
      comparisonOperator:
        cloudwatch.ComparisonOperator.GREATER_THAN_OR_EQUAL_TO_THRESHOLD,
      actionsEnabled: true,
    },
  );

  lambdaErrorAlarm.addAlarmAction(new cloudwatchActions.SnsAction(alarmTopic));
  lambdaErrorAlarm.addOkAction(new cloudwatchActions.SnsAction(alarmTopic));

  // Create alarm for invocations (monitor for unusual activity)
  const lambdaInvocationsAlarm = new cloudwatch.Alarm(
    scope,
    `${famHelpDesk}-NotificationLambdaInvocationsAlarm-${stage}`,
    {
      alarmName: `${famHelpDesk}-NotificationLambdaInvocationsAlarm-${stage}`,
      metric: lambdaInvocationsMetric,
      threshold: 100, // Alert if more than 100 invocations in 5 minutes (adjust as needed)
      evaluationPeriods: 1,
      datapointsToAlarm: 1,
      treatMissingData: cloudwatch.TreatMissingData.NOT_BREACHING,
      alarmDescription: `${famHelpDesk} Notification Lambda Invocations Alarm (${stage}): Monitor for high notification processor activity`,
      comparisonOperator: cloudwatch.ComparisonOperator.GREATER_THAN_THRESHOLD,
      actionsEnabled: false, // No actions, just for monitoring
    },
  );

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
    },
  );

  pushNotificationFailureRateAlarm.addAlarmAction(
    new cloudwatchActions.SnsAction(alarmTopic),
  );
  pushNotificationFailureRateAlarm.addOkAction(
    new cloudwatchActions.SnsAction(alarmTopic),
  );

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
    },
  );

  devicesDisabledAlarm.addAlarmAction(
    new cloudwatchActions.SnsAction(alarmTopic),
  );
  devicesDisabledAlarm.addOkAction(new cloudwatchActions.SnsAction(alarmTopic));

  // Create custom metrics for APNs-specific errors
  const apnsRateLimitErrorsMetric = new cloudwatch.Metric({
    namespace: `${famHelpDesk}/Notifications`,
    metricName: "APNsRateLimitErrors",
    dimensionsMap: {
      Stage: stage,
    },
    statistic: "Sum",
    period: Duration.minutes(5),
  });

  const apnsServerErrorsMetric = new cloudwatch.Metric({
    namespace: `${famHelpDesk}/Notifications`,
    metricName: "APNsServerErrors",
    dimensionsMap: {
      Stage: stage,
    },
    statistic: "Sum",
    period: Duration.minutes(5),
  });

  // Create alarm for APNs rate limit errors
  const apnsRateLimitAlarm = new cloudwatch.Alarm(
    scope,
    `${famHelpDesk}-APNsRateLimitAlarm-${stage}`,
    {
      alarmName: `${famHelpDesk}-APNsRateLimitAlarm-${stage}`,
      metric: apnsRateLimitErrorsMetric,
      threshold: 5, // Alert if more than 5 rate limit errors in 5 minutes
      evaluationPeriods: 1,
      datapointsToAlarm: 1,
      treatMissingData: cloudwatch.TreatMissingData.NOT_BREACHING,
      alarmDescription: `${famHelpDesk} APNs Rate Limit Alarm (${stage}): Alert when APNs rate limit errors exceed 5 in 5 minutes`,
      comparisonOperator: cloudwatch.ComparisonOperator.GREATER_THAN_THRESHOLD,
      actionsEnabled: true,
    },
  );

  apnsRateLimitAlarm.addAlarmAction(
    new cloudwatchActions.SnsAction(alarmTopic),
  );
  apnsRateLimitAlarm.addOkAction(new cloudwatchActions.SnsAction(alarmTopic));

  // Create alarm for APNs server errors
  const apnsServerErrorAlarm = new cloudwatch.Alarm(
    scope,
    `${famHelpDesk}-APNsServerErrorAlarm-${stage}`,
    {
      alarmName: `${famHelpDesk}-APNsServerErrorAlarm-${stage}`,
      metric: apnsServerErrorsMetric,
      threshold: 10, // Alert if more than 10 server errors in 5 minutes
      evaluationPeriods: 1,
      datapointsToAlarm: 1,
      treatMissingData: cloudwatch.TreatMissingData.NOT_BREACHING,
      alarmDescription: `${famHelpDesk} APNs Server Error Alarm (${stage}): Alert when APNs server errors exceed 10 in 5 minutes`,
      comparisonOperator: cloudwatch.ComparisonOperator.GREATER_THAN_THRESHOLD,
      actionsEnabled: true,
    },
  );

  apnsServerErrorAlarm.addAlarmAction(
    new cloudwatchActions.SnsAction(alarmTopic),
  );
  apnsServerErrorAlarm.addOkAction(new cloudwatchActions.SnsAction(alarmTopic));

  // Create CloudWatch Dashboard
  const dashboard = new cloudwatch.Dashboard(
    scope,
    `${famHelpDesk}-NotificationDashboard-${stage}`,
    {
      dashboardName: `${famHelpDesk}-NotificationDashboard-${stage}`,
    },
  );

  // Add widgets to dashboard
  dashboard.addWidgets(
    // Row 1: Push Notification Success/Failure
    new cloudwatch.GraphWidget({
      title: "Push Notifications - Success vs Failed",
      left: [pushNotificationsSentMetric, pushNotificationsFailedMetric],
      width: 12,
      height: 6,
      legendPosition: cloudwatch.LegendPosition.BOTTOM,
    }),
    new cloudwatch.GraphWidget({
      title: "Push Notification Failure Rate (%)",
      left: [
        new cloudwatch.MathExpression({
          expression:
            "IF(sent + failed > 0, failed / (sent + failed) * 100, 0)",
          usingMetrics: {
            sent: pushNotificationsSentMetric,
            failed: pushNotificationsFailedMetric,
          },
          label: "Failure Rate %",
          period: Duration.minutes(5),
        }),
      ],
      width: 12,
      height: 6,
      legendPosition: cloudwatch.LegendPosition.BOTTOM,
      leftYAxis: {
        min: 0,
        max: 100,
      },
    }),
  );

  dashboard.addWidgets(
    // Row 2: Device Management
    new cloudwatch.GraphWidget({
      title: "Devices Disabled",
      left: [devicesDisabledMetric],
      width: 12,
      height: 6,
      legendPosition: cloudwatch.LegendPosition.BOTTOM,
    }),
    new cloudwatch.GraphWidget({
      title: "APNs Error Types",
      left: [apnsRateLimitErrorsMetric, apnsServerErrorsMetric],
      width: 12,
      height: 6,
      legendPosition: cloudwatch.LegendPosition.BOTTOM,
    }),
  );

  dashboard.addWidgets(
    // Row 3: Lambda Metrics
    new cloudwatch.GraphWidget({
      title: "Notification Processor - Invocations",
      left: [lambdaInvocationsMetric],
      width: 12,
      height: 6,
      legendPosition: cloudwatch.LegendPosition.BOTTOM,
    }),
    new cloudwatch.GraphWidget({
      title: "Notification Processor - Errors",
      left: [lambdaErrorMetric],
      width: 12,
      height: 6,
      legendPosition: cloudwatch.LegendPosition.BOTTOM,
    }),
  );

  dashboard.addWidgets(
    // Row 4: DLQ and Alarm Status
    new cloudwatch.GraphWidget({
      title: "Notification DLQ - Message Count",
      left: [dlqMessageCountMetric],
      width: 8,
      height: 6,
      legendPosition: cloudwatch.LegendPosition.BOTTOM,
    }),
    new cloudwatch.GraphWidget({
      title: "iOS Push DLQ - Message Count",
      left: [iosPushDlqMessageCountMetric],
      width: 8,
      height: 6,
      legendPosition: cloudwatch.LegendPosition.BOTTOM,
    }),
    new cloudwatch.AlarmStatusWidget({
      title: "Alarm Status",
      alarms: [
        dlqAlarm,
        iosPushDlqAlarm,
        lambdaErrorAlarm,
        pushNotificationFailureRateAlarm,
        devicesDisabledAlarm,
        apnsRateLimitAlarm,
        apnsServerErrorAlarm,
      ],
      width: 8,
      height: 6,
    }),
  );

  return {
    dlqMessageCountMetric,
    dlqAlarm,
    iosPushDlqMessageCountMetric,
    iosPushDlqAlarm,
    lambdaErrorMetric,
    lambdaInvocationsMetric,
    lambdaErrorAlarm,
    lambdaInvocationsAlarm,
    alarmTopic,
    pushNotificationsSentMetric,
    pushNotificationsFailedMetric,
    devicesDisabledMetric,
    apnsRateLimitErrorsMetric,
    apnsServerErrorsMetric,
    pushNotificationFailureRateAlarm,
    devicesDisabledAlarm,
    apnsRateLimitAlarm,
    apnsServerErrorAlarm,
    dashboard,
  };
}
