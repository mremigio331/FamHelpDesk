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

export function addUserDeleteMonitoring(
  scope: Stack,
  stage: string,
  deadLetterQueue: sqs.Queue,
  userDeleteLambda: lambda.Function,
  escalationEmail: string,
) {
  // Create SNS Topic for alarm notifications
  const alarmTopic = new sns.Topic(
    scope,
    `${famHelpDesk}-UserDeleteAlarmTopic-${stage}`,
    {
      topicName: `${famHelpDesk}-UserDeleteAlarmTopic-${stage}`,
      displayName: `${famHelpDesk} User Delete Alarm Topic (${stage})`,
    },
  );

  // Add email subscription for alerts
  alarmTopic.addSubscription(new subs.EmailSubscription(escalationEmail));

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
    `${famHelpDesk}-UserDeleteDLQAlarm-${stage}-${scope.node.addr}`,
    {
      alarmName: `${famHelpDesk}-UserDeleteDLQAlarm-${stage}-${scope.node.addr}`,
      metric: dlqMessageCountMetric,
      threshold: 1,
      evaluationPeriods: 1,
      alarmDescription: `${famHelpDesk} User Delete DLQ Alarm (${stage}): Alert when messages are in the dead letter queue`,
    },
  );

  // Add alarm actions
  dlqAlarm.addAlarmAction(new cloudwatchActions.SnsAction(alarmTopic));
  dlqAlarm.addOkAction(new cloudwatchActions.SnsAction(alarmTopic));

  // Create Lambda invocation metric
  const lambdaInvocationMetric = userDeleteLambda.metricInvocations({
    period: Duration.minutes(1),
  });

  return { dlqAlarm, lambdaInvocationMetric };
}
