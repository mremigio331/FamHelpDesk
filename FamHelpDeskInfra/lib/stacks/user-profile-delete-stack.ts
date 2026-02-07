import { Stack, StackProps, Duration } from "aws-cdk-lib";
import { Construct } from "constructs";
import * as sns from "aws-cdk-lib/aws-sns";
import * as sqs from "aws-cdk-lib/aws-sqs";
import * as lambda from "aws-cdk-lib/aws-lambda";
import * as snsSubscriptions from "aws-cdk-lib/aws-sns-subscriptions";
import * as dynamodb from "aws-cdk-lib/aws-dynamodb";
import * as iam from "aws-cdk-lib/aws-iam";
import * as path from "path";
import { addUserDeleteMonitoring } from "../monitoring/user-delete-monitoring";
import { createPythonLambdaLayer } from "../helpers/lambda-layer-helper";

interface UserProfileDeleteStackProps extends StackProps {
  stage: string;
  escalationEmail: string;
  escalationNumber: string;
  senderEmail: string;
  cognitoUserPoolId: string;
  userTable: dynamodb.ITable;
  notificationQueue: sqs.IQueue;
}

export class UserProfileDeleteStack extends Stack {
  public readonly userDeleteLambda: lambda.Function;
  public readonly userDeleteLambdaArn: string;

  constructor(scope: Construct, id: string, props: UserProfileDeleteStackProps) {
    super(scope, id, props);

    const { stage, escalationEmail, escalationNumber, senderEmail, cognitoUserPoolId, userTable, notificationQueue } = props;

    // Update Dead Letter Queue name
    const dlq = new sqs.Queue(this, `FamHelpDesk-UserDeleteDLQ-${stage}`, {
      queueName: `FamHelpDesk-UserDeleteDLQ-${stage}`,
      retentionPeriod: Duration.days(14),
    });

    // Update SNS topic name for admin notifications (separate from user notifications)
    const adminNotificationTopic = new sns.Topic(this, `FamHelpDesk-UserDeleteNotificationTopic-${stage}`, {
      topicName: `FamHelpDesk-UserDeleteNotificationTopic-${stage}`,
      displayName: `FamHelpDesk User Deletion Admin Notifications - ${stage}`,
    });

    // Subscribe email and phone number to the admin notification topic
    adminNotificationTopic.addSubscription(new snsSubscriptions.EmailSubscription(escalationEmail));
    adminNotificationTopic.addSubscription(new snsSubscriptions.SmsSubscription(escalationNumber));

    // Update Lambda function name
    this.userDeleteLambda = new lambda.Function(this, `FamHelpDesk-UserDeleteLambda-${stage}`, {
      functionName: `FamHelpDesk-UserDeleteLambda-${stage}`,
      runtime: lambda.Runtime.PYTHON_3_11,
      handler: "user_delete_lambda.lambda_handler",
      code: lambda.Code.fromAsset(path.join(__dirname, "../../../FamHelpDeskBackend")),
      timeout: Duration.minutes(15),
      memorySize: 256,
      environment: {
        STAGE: stage,
        NOTIFICATION_TOPIC_ARN: adminNotificationTopic.topicArn, // Admin notifications via SNS
        NOTIFICATION_QUEUE_URL: notificationQueue.queueUrl, // User notifications via SQS
        SENDER_EMAIL: senderEmail,
        COGNITO_REGION: this.region,
        COGNITO_USER_POOL_ID: cognitoUserPoolId,
        TABLE_NAME: userTable.tableName,
      },
      deadLetterQueue: dlq,
    });

    // Export the Lambda ARN for other stacks to reference
    this.userDeleteLambdaArn = this.userDeleteLambda.functionArn;

    // Add SES permissions to the Lambda function
    this.userDeleteLambda.addToRolePolicy(
      new iam.PolicyStatement({
        actions: ["ses:SendEmail", "ses:SendRawEmail"],
        resources: ["*"], // Adjust to specific SES resources if needed
      })
    );

    // Grant permissions to the Cognito User Pool
    this.userDeleteLambda.addToRolePolicy(
      new iam.PolicyStatement({
        actions: ["cognito-idp:AdminDeleteUser"],
        resources: [
          `arn:aws:cognito-idp:${this.region}:${this.account}:userpool/${cognitoUserPoolId}` // Grant access to the specific Cognito User Pool
        ],
      })
    );

    // Grant permissions to publish to the admin SNS topic
    adminNotificationTopic.grantPublish(this.userDeleteLambda);

    // Grant permissions to send messages to the notification queue
    notificationQueue.grantSendMessages(this.userDeleteLambda);

    // Grant permissions to the DynamoDB table
    userTable.grantReadWriteData(this.userDeleteLambda);

    // Use the shared Python Lambda Layer
    const pythonLayer = createPythonLambdaLayer(this, stage);
    this.userDeleteLambda.addLayers(pythonLayer);

    // Add monitoring for the user delete Lambda and DLQ
    addUserDeleteMonitoring(
      this,
      stage,
      dlq,
      this.userDeleteLambda,
      escalationEmail
    );
  }
}