import {
  Stack,
  StackProps,
  Duration,
  aws_cloudwatch as cloudwatch,
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
}

export class DashboardStack extends Stack {
  public readonly dashboard: cloudwatch.Dashboard;

  constructor(scope: Construct, id: string, props: DashboardStackProps) {
    super(scope, id, props);

    const { stage, apiMetrics, cognitoMetrics, notificationMetrics } = props;

    // Create the dashboard
    this.dashboard = new cloudwatch.Dashboard(
      this,
      `${famHelpDesk}-Dashboard-${stage}`,
      {
        dashboardName: `${famHelpDesk}-Dashboard-${stage}`,
      },
    );

    // === COGNITO METRICS ===
    // Using metrics from cognitoMetrics instead of creating new ones

    // === DASHBOARD WIDGETS ===

    // API 2XX Success Widget
    const api2xxWidget = new cloudwatch.GraphWidget({
      title: "API Gateway - 2XX Success Responses",
      left: [apiMetrics.api2xxMetric],
      leftYAxis: {
        label: "Success Count",
        showUnits: false,
      },
      width: 8,
      height: 6,
      period: Duration.minutes(5),
      leftAnnotations: [
        {
          value: 10,
          label: "Low Success Threshold",
          color: cloudwatch.Color.ORANGE,
        },
      ],
    });

    // API 4XX Error Widget
    const api4xxWidget = new cloudwatch.GraphWidget({
      title: "API Gateway - 4XX Client Errors",
      left: [apiMetrics.api4xxMetric],
      leftYAxis: {
        label: "Error Count",
        showUnits: false,
      },
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

    // API 5XX Error Widget
    const api5xxWidget = new cloudwatch.GraphWidget({
      title: "API Gateway - 5XX Server Errors",
      left: [apiMetrics.api5xxMetric],
      leftYAxis: {
        label: "Error Count",
        showUnits: false,
      },
      width: 8,
      height: 6,
      period: Duration.minutes(5),
      leftAnnotations: [
        {
          value: 1,
          label: "Critical Error Threshold",
          color: cloudwatch.Color.RED,
        },
      ],
    });

    // Cognito Lambda Invocations Widget
    const cognitoInvocationsWidget = new cloudwatch.GraphWidget({
      title: "Cognito - User Event Logger Invocations",
      left: [cognitoMetrics.invocationsMetric],
      leftYAxis: {
        label: "Invocations",
        showUnits: false,
      },
      width: 8,
      height: 6,
      period: Duration.minutes(5),
      leftAnnotations: [
        {
          value: 50,
          label: "High Activity Threshold",
          color: cloudwatch.Color.ORANGE,
        },
      ],
    });

    // Cognito Error Widget
    const cognitoErrorWidget = new cloudwatch.GraphWidget({
      title: "Cognito - User Event Logger Errors",
      left: [cognitoMetrics.errorMetric.metric()],
      leftYAxis: {
        label: "Error Count",
        showUnits: false,
      },
      width: 8,
      height: 6,
      period: Duration.minutes(5),
      leftAnnotations: [
        {
          value: 0,
          label: "Error Threshold",
          color: cloudwatch.Color.RED,
        },
      ],
    });

    // Notification Lambda Invocations Widget
    const notificationInvocationsWidget = new cloudwatch.GraphWidget({
      title: "Notification - Processor Invocations",
      left: [notificationMetrics.lambdaInvocationsMetric],
      leftYAxis: {
        label: "Invocations",
        showUnits: false,
      },
      width: 8,
      height: 6,
      period: Duration.minutes(5),
      leftAnnotations: [
        {
          value: 100,
          label: "High Activity Threshold",
          color: cloudwatch.Color.ORANGE,
        },
      ],
    });

    // Notification DLQ Widget
    const notificationDlqWidget = new cloudwatch.GraphWidget({
      title: "Notification - Dead Letter Queue",
      left: [notificationMetrics.dlqMessageCountMetric],
      leftYAxis: {
        label: "Message Count",
        showUnits: false,
      },
      width: 8,
      height: 6,
      period: Duration.minutes(1),
      leftAnnotations: [
        {
          value: 1,
          label: "DLQ Alert Threshold",
          color: cloudwatch.Color.RED,
        },
      ],
    });

    // Notification Lambda Errors Widget
    const notificationErrorWidget = new cloudwatch.GraphWidget({
      title: "Notification - Processor Errors",
      left: [notificationMetrics.lambdaErrorMetric],
      leftYAxis: {
        label: "Error Count",
        showUnits: false,
      },
      width: 8,
      height: 6,
      period: Duration.minutes(5),
      leftAnnotations: [
        {
          value: 1,
          label: "Error Alert Threshold",
          color: cloudwatch.Color.RED,
        },
      ],
    });

    // Add widgets to dashboard in organized rows
    // Row 1: API Metrics
    this.dashboard.addWidgets(api2xxWidget, api4xxWidget, api5xxWidget);
    
    // Row 2: Cognito Metrics
    this.dashboard.addWidgets(cognitoInvocationsWidget, cognitoErrorWidget);
    
    // Row 3: Notification Metrics
    this.dashboard.addWidgets(notificationInvocationsWidget, notificationDlqWidget, notificationErrorWidget);
  }
}