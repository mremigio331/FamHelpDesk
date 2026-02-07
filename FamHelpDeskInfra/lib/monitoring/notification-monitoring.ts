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

  return {
    dlqMessageCountMetric,
    dlqAlarm,
    lambdaErrorMetric,
    lambdaInvocationsMetric,
    lambdaErrorAlarm,
    lambdaInvocationsAlarm,
    alarmTopic,
  };
}