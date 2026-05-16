import {
  Stack,
  StackProps,
  Duration,
  aws_cloudwatch as cloudwatch,
  aws_lambda as lambda,
} from "aws-cdk-lib";
import { Construct } from "constructs";
import { famHelpDesk } from "../constants";
import { ApiMetrics } from "../monitoring/api-monitoring";
import { CognitoMetrics } from "../monitoring/cognito-monitoring";
import { NotificationMetrics } from "../monitoring/notification-monitoring";

interface DashboardStackProps extends StackProps {
  stage: string;
  apiMetrics: ApiMetrics;
  cognitoMetrics: CognitoMetrics;
  notificationMetrics: NotificationMetrics;
  apiLambda: lambda.Function;
  notificationProcessor: lambda.Function;
  iosPushProcessor: lambda.Function;
  cognitoLambda: lambda.Function;
  userDeleteLambda: lambda.Function;
  familyDeleteLambda: lambda.Function;
}

export class DashboardStack extends Stack {
  public readonly dashboard: cloudwatch.Dashboard;

  constructor(scope: Construct, id: string, props: DashboardStackProps) {
    super(scope, id, props);

    const {
      stage,
      apiMetrics,
      cognitoMetrics,
      notificationMetrics,
      apiLambda,
      notificationProcessor,
      iosPushProcessor,
      cognitoLambda,
      userDeleteLambda,
      familyDeleteLambda,
    } = props;

    // Create the dashboard
    this.dashboard = new cloudwatch.Dashboard(
      this,
      `${famHelpDesk}-Dashboard-${stage}`,
      {
        dashboardName: `${famHelpDesk}-Dashboard-${stage}`,
      },
    );

    const metricsNamespace = `FamHelpDesk-${stage.toUpperCase()}`;

    // === ROW 1: API Gateway Metrics ===

    // 2XX is calculated as Count - 4XX - 5XX
    const apiCountMetric = new cloudwatch.Metric({
      namespace: "AWS/ApiGateway",
      metricName: "Count",
      dimensionsMap: {
        ApiName: `${famHelpDesk}-Api-${stage}`,
      },
      statistic: "Sum",
      period: Duration.minutes(5),
    });

    const api2xxWidget = new cloudwatch.GraphWidget({
      title: "API Gateway - Total Requests",
      left: [apiCountMetric],
      width: 8,
      height: 6,
      period: Duration.minutes(5),
    });

    const api4xxWidget = new cloudwatch.GraphWidget({
      title: "API Gateway - 4XX Client Errors",
      left: [apiMetrics.api4xxMetric],
      width: 8,
      height: 6,
      period: Duration.minutes(5),
      leftAnnotations: [
        {
          value: 5,
          label: "High Error Threshold",
          color: cloudwatch.Color.ORANGE,
        },
      ],
    });

    const api5xxWidget = new cloudwatch.GraphWidget({
      title: "API Gateway - 5XX Server Errors",
      left: [apiMetrics.api5xxMetric],
      width: 8,
      height: 6,
      period: Duration.minutes(5),
      leftAnnotations: [
        { value: 1, label: "Critical", color: cloudwatch.Color.RED },
      ],
    });

    // === ROW 2: All Lambda Invocations ===

    const allLambdaInvocationsWidget = new cloudwatch.GraphWidget({
      title: "All Lambda Invocations",
      left: [
        apiLambda.metricInvocations({ label: "API Lambda" }),
        notificationProcessor.metricInvocations({
          label: "Notification Processor",
        }),
        iosPushProcessor.metricInvocations({ label: "iOS Push Processor" }),
        cognitoLambda.metricInvocations({ label: "Cognito Event Logger" }),
        userDeleteLambda.metricInvocations({ label: "User Delete" }),
        familyDeleteLambda.metricInvocations({ label: "Family Delete" }),
      ],
      width: 12,
      height: 6,
      period: Duration.minutes(5),
    });

    const allLambdaErrorsWidget = new cloudwatch.GraphWidget({
      title: "All Lambda Errors",
      left: [
        apiLambda.metricErrors({ label: "API Lambda" }),
        notificationProcessor.metricErrors({ label: "Notification Processor" }),
        iosPushProcessor.metricErrors({ label: "iOS Push Processor" }),
        cognitoLambda.metricErrors({ label: "Cognito Event Logger" }),
        userDeleteLambda.metricErrors({ label: "User Delete" }),
        familyDeleteLambda.metricErrors({ label: "Family Delete" }),
      ],
      width: 12,
      height: 6,
      period: Duration.minutes(5),
      leftAnnotations: [
        { value: 1, label: "Error Alert", color: cloudwatch.Color.RED },
      ],
    });

    // === ROW 3: Lambda Duration & Throttles ===

    const allLambdaDurationWidget = new cloudwatch.GraphWidget({
      title: "Lambda Duration (Avg ms)",
      left: [
        apiLambda.metricDuration({ label: "API Lambda", statistic: "Average" }),
        notificationProcessor.metricDuration({
          label: "Notification Processor",
          statistic: "Average",
        }),
        iosPushProcessor.metricDuration({
          label: "iOS Push Processor",
          statistic: "Average",
        }),
      ],
      width: 12,
      height: 6,
      period: Duration.minutes(5),
    });

    const allLambdaThrottlesWidget = new cloudwatch.GraphWidget({
      title: "Lambda Throttles",
      left: [
        apiLambda.metricThrottles({ label: "API Lambda" }),
        notificationProcessor.metricThrottles({
          label: "Notification Processor",
        }),
        iosPushProcessor.metricThrottles({ label: "iOS Push Processor" }),
      ],
      width: 12,
      height: 6,
      period: Duration.minutes(5),
    });

    // === ROW 4: FamGrab Order Metrics ===

    const orderCreatedWidget = new cloudwatch.GraphWidget({
      title: "FamGrab - Orders Created",
      left: [
        new cloudwatch.MathExpression({
          expression: `SEARCH('{${metricsNamespace},FamilyId} MetricName="OrderCreated"', 'Sum', 300)`,
          label: "Orders Created",
          period: Duration.minutes(5),
        }),
      ],
      width: 12,
      height: 6,
      period: Duration.minutes(5),
    });

    const orderConfirmedWidget = new cloudwatch.GraphWidget({
      title: "FamGrab - Confirmations (Orders & Items)",
      left: [
        new cloudwatch.MathExpression({
          expression: `SEARCH('{${metricsNamespace},FamilyId} MetricName="OrderConfirmed"', 'Sum', 300)`,
          label: "Orders Confirmed",
          period: Duration.minutes(5),
        }),
        new cloudwatch.MathExpression({
          expression: `SEARCH('{${metricsNamespace},FamilyId} MetricName="ItemConfirmed"', 'Sum', 300)`,
          label: "Items Confirmed",
          period: Duration.minutes(5),
        }),
      ],
      width: 12,
      height: 6,
      period: Duration.minutes(5),
    });

    // === ROW 5: Ticket Metrics (all on one graph) ===

    const ticketMetricsWidget = new cloudwatch.GraphWidget({
      title: "Tickets - Activity",
      left: [
        new cloudwatch.MathExpression({
          expression: `SEARCH('{${metricsNamespace},FamilyId} MetricName="TicketCreated"', 'Sum', 300)`,
          label: "Created",
          period: Duration.minutes(5),
        }),
        new cloudwatch.MathExpression({
          expression: `SEARCH('{${metricsNamespace},FamilyId} MetricName="TicketResolved"', 'Sum', 300)`,
          label: "Resolved",
          period: Duration.minutes(5),
        }),
        new cloudwatch.MathExpression({
          expression: `SEARCH('{${metricsNamespace},FamilyId} MetricName="TicketComment"', 'Sum', 300)`,
          label: "Comments",
          period: Duration.minutes(5),
        }),
        new cloudwatch.MathExpression({
          expression: `SEARCH('{${metricsNamespace},FamilyId} MetricName="TicketStatusChanged"', 'Sum', 300)`,
          label: "Status Changes",
          period: Duration.minutes(5),
        }),
      ],
      width: 24,
      height: 6,
      period: Duration.minutes(5),
    });

    // === ROW 5: Notification Infrastructure ===

    const notificationInvocationsWidget = new cloudwatch.GraphWidget({
      title: "Notification Processor Invocations",
      left: [notificationMetrics.lambdaInvocationsMetric],
      width: 8,
      height: 6,
      period: Duration.minutes(5),
    });

    const notificationDlqWidget = new cloudwatch.GraphWidget({
      title: "Notification DLQ Messages",
      left: [notificationMetrics.dlqMessageCountMetric],
      width: 8,
      height: 6,
      period: Duration.minutes(1),
      leftAnnotations: [
        { value: 1, label: "DLQ Alert", color: cloudwatch.Color.RED },
      ],
    });

    const notificationErrorWidget = new cloudwatch.GraphWidget({
      title: "Notification Processor Errors",
      left: [notificationMetrics.lambdaErrorMetric],
      width: 8,
      height: 6,
      period: Duration.minutes(5),
      leftAnnotations: [
        { value: 1, label: "Error Alert", color: cloudwatch.Color.RED },
      ],
    });

    // === ROW 6: Cognito ===

    const cognitoInvocationsWidget = new cloudwatch.GraphWidget({
      title: "Cognito Event Logger Invocations",
      left: [cognitoMetrics.invocationsMetric],
      width: 12,
      height: 6,
      period: Duration.minutes(5),
    });

    const cognitoErrorWidget = new cloudwatch.GraphWidget({
      title: "Cognito Event Logger Errors",
      left: [cognitoMetrics.errorMetric.metric()],
      width: 12,
      height: 6,
      period: Duration.minutes(5),
      leftAnnotations: [
        { value: 1, label: "Error Alert", color: cloudwatch.Color.RED },
      ],
    });

    // === Add all widgets to dashboard ===

    // Row 1: API Gateway
    this.dashboard.addWidgets(api2xxWidget, api4xxWidget, api5xxWidget);

    // Row 2: All Lambda Invocations & Errors
    this.dashboard.addWidgets(
      allLambdaInvocationsWidget,
      allLambdaErrorsWidget,
    );

    // Row 3: Lambda Duration & Throttles
    this.dashboard.addWidgets(
      allLambdaDurationWidget,
      allLambdaThrottlesWidget,
    );

    // Row 4: FamGrab Order Metrics
    this.dashboard.addWidgets(orderCreatedWidget, orderConfirmedWidget);

    // Row 5: Ticket Metrics
    this.dashboard.addWidgets(ticketMetricsWidget);

    // Row 6: Notification Infrastructure
    this.dashboard.addWidgets(
      notificationInvocationsWidget,
      notificationDlqWidget,
      notificationErrorWidget,
    );

    // Row 7: Cognito
    this.dashboard.addWidgets(cognitoInvocationsWidget, cognitoErrorWidget);
  }
}
