import { Stack, Duration } from "aws-cdk-lib";
import * as logs from "aws-cdk-lib/aws-logs";
import * as lambda from "aws-cdk-lib/aws-lambda";
import * as cloudwatch from "aws-cdk-lib/aws-cloudwatch";
import { famHelpDesk } from "../constants";

export interface CognitoMetrics {
  errorMetric: logs.MetricFilter;
  errorAlarm: cloudwatch.Alarm;
  invocationsMetric: cloudwatch.Metric;
  invocationsAlarm: cloudwatch.Alarm;
}

export function addCognitoMonitoring(
  scope: Stack,
  logGroup: logs.LogGroup,
  userEventLoggerFunction: lambda.Function,
  stage: string,
): CognitoMetrics {
  // CloudWatch Metric Filter for ERROR log lines
  const errorMetric = new logs.MetricFilter(
    scope,
    `${famHelpDesk}-UserEventLoggerErrorMetric-${stage}`,
    {
      logGroup,
      metricNamespace: `${famHelpDesk}/UserEventLogger`,
      metricName: `ErrorCount-${stage}`,
      filterPattern: logs.FilterPattern.literal('"ERROR"'),
      metricValue: "1",
    },
  );

  // CloudWatch Alarm for ERROR log lines in the last 30 minutes
  const errorAlarm = new cloudwatch.Alarm(
    scope,
    `${famHelpDesk}-UserEventLoggerErrorAlarm-${stage}`,
    {
      alarmName: `${famHelpDesk}-UserEventLogger-ErrorAlarm-${stage}`,
      metric: errorMetric.metric({
        statistic: "Sum",
        period: Duration.minutes(30),
      }),
      threshold: 0,
      evaluationPeriods: 1,
      comparisonOperator: cloudwatch.ComparisonOperator.GREATER_THAN_THRESHOLD,
      treatMissingData: cloudwatch.TreatMissingData.NOT_BREACHING,
    },
  );

  // Create Lambda invocations metric for monitoring
  const invocationsMetric = new cloudwatch.Metric({
    namespace: "AWS/Lambda",
    metricName: "Invocations",
    dimensionsMap: {
      FunctionName: userEventLoggerFunction.functionName,
    },
    statistic: "Sum",
    period: Duration.minutes(5),
  });

  // Create alarm for invocations (monitor for unusual activity)
  const invocationsAlarm = new cloudwatch.Alarm(
    scope,
    `${famHelpDesk}-UserEventLoggerInvocationsAlarm-${stage}`,
    {
      alarmName: `${famHelpDesk}-UserEventLogger-InvocationsAlarm-${stage}`,
      metric: invocationsMetric,
      threshold: 50, // Alert if more than 50 invocations in 5 minutes (adjust as needed)
      evaluationPeriods: 1,
      comparisonOperator: cloudwatch.ComparisonOperator.GREATER_THAN_THRESHOLD,
      treatMissingData: cloudwatch.TreatMissingData.NOT_BREACHING,
      actionsEnabled: false, // No actions, just for monitoring
    },
  );

  return {
    errorMetric,
    errorAlarm,
    invocationsMetric,
    invocationsAlarm,
  };
}
