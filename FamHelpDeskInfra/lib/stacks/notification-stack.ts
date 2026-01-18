import { Stack, StackProps, Duration } from "aws-cdk-lib";
import { Construct } from "constructs";
import * as sns from "aws-cdk-lib/aws-sns";
import * as sqs from "aws-cdk-lib/aws-sqs";
import * as lambda from "aws-cdk-lib/aws-lambda";
import * as snsSubscriptions from "aws-cdk-lib/aws-sns-subscriptions";
import * as dynamodb from "aws-cdk-lib/aws-dynamodb";
import * as iam from "aws-cdk-lib/aws-iam";
import * as cloudwatchActions from "aws-cdk-lib/aws-cloudwatch-actions";
import * as path from "path";
import { addNotificationMonitoring, NotificationMetrics } from "../monitoring/notification-monitoring";
import { famHelpDesk } from "../constants";

interface NotificationStackProps extends StackProps {
  stage: string;
  userTable: dynamodb.Table;
  escalationEmail: string;
  escalationNumber: string;
}

export class NotificationStack extends Stack {
  public readonly notificationTopic: sns.Topic;
  public readonly notificationProcessor: lambda.Function;
  public readonly deadLetterQueue: sqs.Queue;
  public readonly alarmTopic: sns.Topic;
  public readonly notificationMetrics: NotificationMetrics;

  constructor(scope: Construct, id: string, props: NotificationStackProps) {
    super(scope, id, props);

    const { stage, userTable, escalationEmail, escalationNumber } = props;

    // Create Lambda layer with dependencies (same as other stacks)
    const layer = new lambda.LayerVersion(
      this,
      `${famHelpDesk}-NotificationLayer-${stage}`,
      {
        code: lambda.Code.fromAsset(
          path.join(__dirname, "../../../FamHelpDeskBackend/lambda_layer.zip"),
        ),
        compatibleRuntimes: [lambda.Runtime.PYTHON_3_11],
        description: `${famHelpDesk} Notification Lambda layer with dependencies - ${stage}`,
      },
    );

    // Create SQS Dead Letter Queue for failed notifications
    this.deadLetterQueue = new sqs.Queue(this, `${famHelpDesk}-NotificationDLQ-${stage}`, {
      queueName: `${famHelpDesk}-NotificationDLQ-${stage}`,
      retentionPeriod: Duration.days(14), // Keep failed messages for 14 days
    });

    // Create SNS topic for notification events
    this.notificationTopic = new sns.Topic(this, `${famHelpDesk}-NotificationTopic-${stage}`, {
      topicName: `${famHelpDesk}-NotificationTopic-${stage}`,
      displayName: `${famHelpDesk} Notification Events - ${stage}`,
    });

    // Create Lambda function to process notifications
    this.notificationProcessor = new lambda.Function(this, `${famHelpDesk}-NotificationProcessor-${stage}`, {
      functionName: `${famHelpDesk}-NotificationProcessor-${stage}`,
      runtime: lambda.Runtime.PYTHON_3_11,
      handler: "notification_processor.lambda_handler",
      code: lambda.Code.fromAsset("../FamHelpDeskBackend"),
      timeout: Duration.minutes(5),
      memorySize: 256,
      layers: [layer],
      environment: {
        STAGE: stage,
        TABLE_NAME: userTable.tableName,
        POWERTOOLS_SERVICE_NAME: "notification-processor",
        POWERTOOLS_LOG_LEVEL: "INFO",
      },
    });

    // Grant DynamoDB permissions to the Lambda function
    userTable.grantReadWriteData(this.notificationProcessor);

    // Add monitoring and alarms
    this.notificationMetrics = addNotificationMonitoring(
      this,
      stage,
      this.deadLetterQueue,
      this.notificationProcessor,
      escalationEmail,
      escalationNumber
    );

    // Store reference to alarm topic for external access
    this.alarmTopic = this.notificationMetrics.alarmTopic;

    // Subscribe Lambda to SNS topic
    this.notificationTopic.addSubscription(
      new snsSubscriptions.LambdaSubscription(this.notificationProcessor, {
        deadLetterQueue: this.deadLetterQueue,
      })
    );

    // Export the topic ARN for use by other stacks
    this.exportValue(this.notificationTopic.topicArn, {
      name: `${famHelpDesk}-NotificationTopicArn-${stage}`,
    });
  }

  /**
   * Grant SNS publish permissions to a Lambda function
   */
  public grantPublishToTopic(lambdaFunction: lambda.Function): void {
    this.notificationTopic.grantPublish(lambdaFunction);
  }
}