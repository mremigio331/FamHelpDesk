import { Stack, StackProps, Duration } from "aws-cdk-lib";
import { Construct } from "constructs";
import * as sns from "aws-cdk-lib/aws-sns";
import * as sqs from "aws-cdk-lib/aws-sqs";
import * as lambda from "aws-cdk-lib/aws-lambda";
import * as snsSubscriptions from "aws-cdk-lib/aws-sns-subscriptions";
import * as dynamodb from "aws-cdk-lib/aws-dynamodb";
import * as iam from "aws-cdk-lib/aws-iam";
import * as cloudwatch from "aws-cdk-lib/aws-cloudwatch";
import * as cloudwatchActions from "aws-cdk-lib/aws-cloudwatch-actions";
import * as path from "path";
import { addUserDeleteMonitoring } from "../monitoring/user-delete-monitoring";
import { createPythonLambdaLayer } from "../helpers/lambda-layer-helper";

interface ResourceDeleteStackProps extends StackProps {
  stage: string;
  escalationEmail: string;
  escalationNumber: string;
  senderEmail: string;
  cognitoUserPoolId: string;
  userTable: dynamodb.ITable;
  notificationQueue: sqs.IQueue;
}

export class ResourceDeleteStack extends Stack {
  public readonly userDeleteLambda: lambda.Function;
  public readonly userDeleteLambdaArn: string;
  public readonly familyDeleteLambda: lambda.Function;
  public readonly familyDeleteLambdaArn: string;

  constructor(scope: Construct, id: string, props: ResourceDeleteStackProps) {
    super(scope, id, props);

    const {
      stage,
      escalationEmail,
      escalationNumber,
      senderEmail,
      cognitoUserPoolId,
      userTable,
      notificationQueue,
    } = props;

    // Create SNS topic for admin notifications (separate from user notifications)
    const adminNotificationTopic = new sns.Topic(
      this,
      `FamHelpDesk-UserDeleteNotificationTopic-${stage}`,
      {
        topicName: `FamHelpDesk-UserDeleteNotificationTopic-${stage}`,
        displayName: `FamHelpDesk User Deletion Admin Notifications - ${stage}`,
      },
    );

    // Subscribe email and phone number to the admin notification topic
    adminNotificationTopic.addSubscription(
      new snsSubscriptions.EmailSubscription(escalationEmail),
    );
    adminNotificationTopic.addSubscription(
      new snsSubscriptions.SmsSubscription(escalationNumber),
    );

    // Update Lambda function name
    this.userDeleteLambda = new lambda.Function(
      this,
      `FamHelpDesk-UserDeleteLambda-${stage}`,
      {
        functionName: `FamHelpDesk-UserDeleteLambda-${stage}`,
        runtime: lambda.Runtime.PYTHON_3_11,
        handler: "lambdas.user_delete_lambda.lambda_handler",
        code: lambda.Code.fromAsset(
          path.join(__dirname, "../../../FamHelpDeskBackend"),
        ),
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
      },
    );

    // Export the Lambda ARN for other stacks to reference
    this.userDeleteLambdaArn = this.userDeleteLambda.functionArn;

    // Add SES permissions to the Lambda function
    this.userDeleteLambda.addToRolePolicy(
      new iam.PolicyStatement({
        actions: ["ses:SendEmail", "ses:SendRawEmail"],
        resources: ["*"], // Adjust to specific SES resources if needed
      }),
    );

    // Grant permissions to the Cognito User Pool
    this.userDeleteLambda.addToRolePolicy(
      new iam.PolicyStatement({
        actions: ["cognito-idp:AdminDeleteUser"],
        resources: [
          `arn:aws:cognito-idp:${this.region}:${this.account}:userpool/${cognitoUserPoolId}`, // Grant access to the specific Cognito User Pool
        ],
      }),
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

    // Add monitoring for the user delete Lambda (error alarm only, no DLQ)
    this.addUserDeleteMonitoring(stage, this.userDeleteLambda, escalationEmail);

    // ===== Family Delete Lambda =====

    // Create SNS topic for Family Delete notifications
    const familyDeleteNotificationTopic = new sns.Topic(
      this,
      `FamHelpDesk-FamilyDeleteNotificationTopic-${stage}`,
      {
        topicName: `FamHelpDesk-FamilyDeleteNotificationTopic-${stage}`,
        displayName: `FamHelpDesk Family Deletion Admin Notifications - ${stage}`,
      },
    );

    // Subscribe email and phone number to the family delete notification topic
    familyDeleteNotificationTopic.addSubscription(
      new snsSubscriptions.EmailSubscription(escalationEmail),
    );
    familyDeleteNotificationTopic.addSubscription(
      new snsSubscriptions.SmsSubscription(escalationNumber),
    );

    // Create Family Delete Lambda
    this.familyDeleteLambda = new lambda.Function(
      this,
      `FamHelpDesk-FamilyDeleteLambda-${stage}`,
      {
        functionName: `FamHelpDesk-FamilyDeleteLambda-${stage}`,
        runtime: lambda.Runtime.PYTHON_3_11,
        handler: "lambdas.family_delete_lambda.lambda_handler",
        code: lambda.Code.fromAsset(
          path.join(__dirname, "../../../FamHelpDeskBackend"),
        ),
        timeout: Duration.minutes(10),
        memorySize: 512,
        environment: {
          STAGE: stage,
          TABLE_NAME: userTable.tableName,
          NOTIFICATION_TOPIC_ARN: familyDeleteNotificationTopic.topicArn,
        },
      },
    );

    // Export the Family Delete Lambda ARN for other stacks to reference
    this.familyDeleteLambdaArn = this.familyDeleteLambda.functionArn;

    // Grant DynamoDB permissions to Family Delete Lambda
    userTable.grantReadWriteData(this.familyDeleteLambda);

    // Grant permissions to publish to the family delete SNS topic
    familyDeleteNotificationTopic.grantPublish(this.familyDeleteLambda);

    // Grant CloudFormation read permissions (for getting exports)
    this.familyDeleteLambda.addToRolePolicy(
      new iam.PolicyStatement({
        actions: [
          "cloudformation:ListExports",
          "cloudformation:DescribeStacks",
        ],
        resources: ["*"],
      }),
    );

    // Use the shared Python Lambda Layer
    this.familyDeleteLambda.addLayers(pythonLayer);

    // Add monitoring for Family Delete Lambda (error alarm only, no DLQ)
    this.addFamilyDeleteMonitoring(
      stage,
      this.familyDeleteLambda,
      escalationEmail,
    );
  }

  private addUserDeleteMonitoring(
    stage: string,
    userDeleteLambda: lambda.Function,
    escalationEmail: string,
  ) {
    // Create SNS Topic for alarm notifications
    const alarmTopic = new sns.Topic(
      this,
      `FamHelpDesk-UserDeleteAlarmTopic-${stage}`,
      {
        topicName: `FamHelpDesk-UserDeleteAlarmTopic-${stage}`,
        displayName: `FamHelpDesk User Delete Alarm Topic (${stage})`,
      },
    );

    // Add email subscription for alerts
    alarmTopic.addSubscription(
      new snsSubscriptions.EmailSubscription(escalationEmail),
    );

    // Create alarm for Lambda errors > 0 in 5 minutes
    const errorMetric = userDeleteLambda.metricErrors({
      period: Duration.minutes(5),
      statistic: "Sum",
    });

    const errorAlarm = new cloudwatch.Alarm(
      this,
      `FamHelpDesk-UserDeleteLambdaErrorAlarm-${stage}`,
      {
        alarmName: `FamHelpDesk-UserDeleteLambdaErrorAlarm-${stage}`,
        metric: errorMetric,
        threshold: 0,
        evaluationPeriods: 1,
        comparisonOperator:
          cloudwatch.ComparisonOperator.GREATER_THAN_THRESHOLD,
        alarmDescription: `FamHelpDesk User Delete Lambda Error Alarm (${stage}): Alert when Lambda errors occur`,
      },
    );

    errorAlarm.addAlarmAction(new cloudwatchActions.SnsAction(alarmTopic));
    errorAlarm.addOkAction(new cloudwatchActions.SnsAction(alarmTopic));
  }

  private addFamilyDeleteMonitoring(
    stage: string,
    familyDeleteLambda: lambda.Function,
    escalationEmail: string,
  ) {
    // Create SNS Topic for alarm notifications
    const alarmTopic = new sns.Topic(
      this,
      `FamHelpDesk-FamilyDeleteAlarmTopic-${stage}`,
      {
        topicName: `FamHelpDesk-FamilyDeleteAlarmTopic-${stage}`,
        displayName: `FamHelpDesk Family Delete Alarm Topic (${stage})`,
      },
    );

    // Add email subscription for alerts
    alarmTopic.addSubscription(
      new snsSubscriptions.EmailSubscription(escalationEmail),
    );

    // Create alarm for Lambda errors > 0 in 5 minutes
    const errorMetric = familyDeleteLambda.metricErrors({
      period: Duration.minutes(5),
      statistic: "Sum",
    });

    const errorAlarm = new cloudwatch.Alarm(
      this,
      `FamHelpDesk-FamilyDeleteLambdaErrorAlarm-${stage}`,
      {
        alarmName: `FamHelpDesk-FamilyDeleteLambdaErrorAlarm-${stage}`,
        metric: errorMetric,
        threshold: 0,
        evaluationPeriods: 1,
        comparisonOperator:
          cloudwatch.ComparisonOperator.GREATER_THAN_THRESHOLD,
        alarmDescription: `FamHelpDesk Family Delete Lambda Error Alarm (${stage}): Alert when Lambda errors occur`,
      },
    );

    errorAlarm.addAlarmAction(new cloudwatchActions.SnsAction(alarmTopic));
    errorAlarm.addOkAction(new cloudwatchActions.SnsAction(alarmTopic));
  }
}
