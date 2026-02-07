import {
  Stack,
  StackProps,
  RemovalPolicy,
  CfnOutput,
  Duration,
  Fn,
} from "aws-cdk-lib";
import { Construct } from "constructs";
import * as cognito from "aws-cdk-lib/aws-cognito";
import * as lambda from "aws-cdk-lib/aws-lambda";
import * as dynamodb from "aws-cdk-lib/aws-dynamodb";
import * as path from "path";
import * as logs from "aws-cdk-lib/aws-logs";
import * as sns from "aws-cdk-lib/aws-sns";
import * as sqs from "aws-cdk-lib/aws-sqs";
import * as subs from "aws-cdk-lib/aws-sns-subscriptions";
import * as secretsmanager from "aws-cdk-lib/aws-secretsmanager";
import { addCognitoMonitoring, CognitoMetrics } from "../monitoring/cognito-monitoring";
import { famHelpDesk } from "../constants";

interface CognitoStackProps extends StackProps {
  callbackUrls: string[];
  stage: string;
  userTable: dynamodb.ITable;
  escalationEmail: string;
  escalationNumber: string;
  googleOathKeys: {
    client_id: string;
    client_secret: string;
  };
  appleOauthKeys: {
    client_id: string;
    team_id: string;
    key_id: string;
    private_key_secret_name: string;
  }
  notificationQueueUrl: string;
}

export class CognitoStack extends Stack {
  public readonly userPool: cognito.UserPool;
  public readonly userPoolClientIOS: cognito.UserPoolClient;
  public readonly userPoolClient: cognito.UserPoolClient;
  public readonly userPoolDomain: cognito.UserPoolDomain;
  public readonly identityPool: cognito.CfnIdentityPool;
  public readonly userEventLoggerFunction: lambda.Function;
  public readonly cognitoMetrics: CognitoMetrics;

  constructor(scope: Construct, id: string, props: CognitoStackProps) {
    super(scope, id, props);

    const {
      callbackUrls,
      userTable,
      stage,
      escalationEmail,
      escalationNumber,
      googleOathKeys,
      appleOauthKeys,
      notificationQueueUrl,
    } = props;

    const layer = new lambda.LayerVersion(
      this,
      `${famHelpDesk}-CognitoLambdaLayer-${stage}`,
      {
        code: lambda.Code.fromAsset(
          path.join(__dirname, "../../../FamHelpDeskBackend/lambda_layer.zip"),
        ),
        compatibleRuntimes: [lambda.Runtime.PYTHON_3_11],
        description: `{${famHelpDesk}} Lambda layer with dependencies`,
      },
    );

    const userAddedTopic = new sns.Topic(
      this,
      `${famHelpDesk}-UserAddedTopic-${stage}`,
      {
        topicName: `${famHelpDesk}-UserAddedTopic-${stage}`,
        displayName: `${famHelpDesk}-User Added Topic (${stage})`,
      },
    );

    userAddedTopic.addSubscription(new subs.EmailSubscription(escalationEmail));
    userAddedTopic.addSubscription(new subs.SmsSubscription(escalationNumber));

    const userEventLogger = new lambda.Function(
      this,
      `${famHelpDesk}-UserEventLogger-${stage}`,
      {
        functionName: `${famHelpDesk}-CognitoUserEventLogger-${stage}`,
        runtime: lambda.Runtime.PYTHON_3_11,
        handler: "cognito_sign_up.handler",
        code: lambda.Code.fromAsset(
          path.join(__dirname, "../../../FamHelpDeskBackend"),
        ),
        tracing: lambda.Tracing.ACTIVE,
        timeout: Duration.minutes(10),
        layers: [layer],
        environment: {
          TABLE_NAME: userTable.tableName,
          POWERTOOLS_LOG_LEVEL: "INFO",
          USER_ADDED_TOPIC_ARN: userAddedTopic.topicArn,
          NOTIFICATION_QUEUE_URL: notificationQueueUrl,
          STAGE: stage
        },
      },
    );

    // Store reference to the function for external access
    this.userEventLoggerFunction = userEventLogger;

    const logGroup = new logs.LogGroup(
      this,
      `${famHelpDesk}-UserEventLoggerLogGroup-${stage}`,
      {
        logGroupName: `/aws/lambda/${famHelpDesk}-CognitoEventLogger-${stage}`,
        retention: logs.RetentionDays.ONE_MONTH,
        removalPolicy: RemovalPolicy.DESTROY,
      },
    );

    userTable.grantReadWriteData(userEventLogger);
    userTable.grantWriteData(userEventLogger);

    userAddedTopic.grantPublish(userEventLogger);

    // Grant permission to send messages to the notification queue
    // Import the queue ARN directly from the NotificationStack export
    const queueArn = Fn.importValue(`${famHelpDesk}-NotificationQueueArn-${stage}`);
    
    const notificationQueue = sqs.Queue.fromQueueArn(
      this,
      `${famHelpDesk}-ImportedNotificationQueue-${stage}`,
      queueArn
    );
    notificationQueue.grantSendMessages(userEventLogger);

    this.cognitoMetrics = addCognitoMonitoring(this, logGroup, userEventLogger, stage);

    this.userPool = new cognito.UserPool(
      this,
      `${famHelpDesk}-UserPool-${stage}`,
      {
        userPoolName: `${famHelpDesk}-UserPool-${stage}`,
        selfSignUpEnabled: true,
        signInAliases: { email: true },
        standardAttributes: {
          email: { required: true, mutable: true }, 
          fullname: { required: true, mutable: true },
          nickname: { required: false, mutable: true },
        },
        passwordPolicy: {
          minLength: 8,
          requireLowercase: true,
          requireUppercase: true,
          requireDigits: true,
          requireSymbols: false,
        },
        accountRecovery: cognito.AccountRecovery.EMAIL_ONLY,
        removalPolicy: RemovalPolicy.DESTROY,
      },
    );

    this.userPool.addTrigger(
      cognito.UserPoolOperation.POST_CONFIRMATION,
      userEventLogger,
    );
    this.userPool.addTrigger(
      cognito.UserPoolOperation.PRE_TOKEN_GENERATION,
      userEventLogger,
    );

    const googleProvider = new cognito.UserPoolIdentityProviderGoogle(
      this,
      `${famHelpDesk}-GoogleProvider-${stage}`,
      {
        userPool: this.userPool,
        clientId: googleOathKeys.client_id,
        clientSecret: googleOathKeys.client_secret,
        scopes: ["openid", "email", "profile"],
        attributeMapping: {
          email: cognito.ProviderAttribute.other("email"),
          fullname: cognito.ProviderAttribute.other("name"),
        },
      },
    );

    // Retrieve Apple private key from Secrets Manager
    const applePrivateKeySecret = secretsmanager.Secret.fromSecretNameV2(
      this,
      `${famHelpDesk}-ApplePrivateKey-${stage}`,
      appleOauthKeys.private_key_secret_name,
    );

    const appleProvider = new cognito.UserPoolIdentityProviderApple(
      this,
      `${famHelpDesk}-AppleProvider-${stage}`,
      {
        userPool: this.userPool,
        clientId: appleOauthKeys.client_id,
        teamId: appleOauthKeys.team_id,
        keyId: appleOauthKeys.key_id,
        privateKeyValue: applePrivateKeySecret.secretValue,
        scopes: ["openid", "email", "name"],
        attributeMapping: {
          email: cognito.ProviderAttribute.other("email"),
          fullname: cognito.ProviderAttribute.other("name"),
        },
      },
    );

    // Explicit attribute permissions for app clients (prevents "Attribute cannot be updated")
    const clientReadAttrs =
      new cognito.ClientAttributes().withStandardAttributes({
        email: true,
        fullname: true,
        nickname: true,
      });

    const clientWriteAttrs =
      new cognito.ClientAttributes().withStandardAttributes({
        email: true,
        fullname: true, // FIX: "name" does not exist in StandardAttributesMask
        nickname: true,
      });

    // =========================
    // WEB APP CLIENT
    // =========================
    this.userPoolClient = new cognito.UserPoolClient(
      this,
      `${famHelpDesk}-UserPoolClient-${stage}`,
      {
        userPool: this.userPool,
        generateSecret: false,
        oAuth: {
          flows: {
            authorizationCodeGrant: true,
          },
          scopes: [
            cognito.OAuthScope.EMAIL,
            cognito.OAuthScope.OPENID,
            cognito.OAuthScope.PROFILE,
          ],
          callbackUrls,
          logoutUrls: callbackUrls,
        },
        supportedIdentityProviders: [
          cognito.UserPoolClientIdentityProvider.COGNITO,
          cognito.UserPoolClientIdentityProvider.GOOGLE,
          cognito.UserPoolClientIdentityProvider.APPLE,
        ],
        readAttributes: clientReadAttrs, // ADDED
        writeAttributes: clientWriteAttrs, // ADDED
        accessTokenValidity: Duration.hours(4),
        idTokenValidity: Duration.hours(4),
        refreshTokenValidity: Duration.days(60),
      },
    );

    this.userPoolClient.node.addDependency(googleProvider);
    this.userPoolClient.node.addDependency(appleProvider);


    const iosCallback = "famHelpDesk://auth/callback";
    const iosLogout = "famHelpDesk://signout";

    this.userPoolClientIOS = new cognito.UserPoolClient(
      this,
      `${famHelpDesk}-UserPoolClientIOS-${stage}`,
      {
        userPool: this.userPool,
        generateSecret: false, // public mobile client → PKCE enforced by Cognito
        oAuth: {
          flows: { authorizationCodeGrant: true },
          scopes: [
            cognito.OAuthScope.OPENID,
            cognito.OAuthScope.EMAIL,
            cognito.OAuthScope.PROFILE,
          ],
          callbackUrls: [iosCallback],
          logoutUrls: [iosLogout],
        },
        enableTokenRevocation: true,
        preventUserExistenceErrors: true,
        supportedIdentityProviders: [
          cognito.UserPoolClientIdentityProvider.COGNITO,
          cognito.UserPoolClientIdentityProvider.GOOGLE,
          cognito.UserPoolClientIdentityProvider.APPLE,
        ],
        readAttributes: clientReadAttrs,
        writeAttributes: clientWriteAttrs,
        accessTokenValidity: Duration.hours(24),
        idTokenValidity: Duration.hours(24),
        refreshTokenValidity: Duration.days(3650),
      },
    );

    this.userPoolClientIOS.node.addDependency(googleProvider);
    this.userPoolClientIOS.node.addDependency(appleProvider);

    this.userPoolDomain = new cognito.UserPoolDomain(
      this,
      `${famHelpDesk}-CognitoDomain-${stage}`,
      {
        userPool: this.userPool,
        cognitoDomain: {
          domainPrefix: `${famHelpDesk.toLocaleLowerCase()}-${stage.toLowerCase()}`,
        },
      },
    );

    this.identityPool = new cognito.CfnIdentityPool(
      this,
      `${famHelpDesk}-IdentityPool-${stage}`,
      {
        allowUnauthenticatedIdentities: false,
        cognitoIdentityProviders: [
          {
            clientId: this.userPoolClient.userPoolClientId,
            providerName: this.userPool.userPoolProviderName,
          },
          {
            clientId: this.userPoolClientIOS.userPoolClientId,
            providerName: this.userPool.userPoolProviderName,
          },
        ],
      },
    );

    new CfnOutput(this, `${famHelpDesk}-UserPoolId-${stage}`, {
      value: this.userPool.userPoolId,
    });

    new CfnOutput(this, `${famHelpDesk}-UserPoolClientId-${stage}`, {
      value: this.userPoolClient.userPoolClientId,
    });

    new CfnOutput(this, `${famHelpDesk}-UserPoolClientIOSId-${stage}`, {
      value: this.userPoolClientIOS.userPoolClientId,
    });

    new CfnOutput(this, `${famHelpDesk}-UserPoolDomain-${stage}`, {
      value: `${this.userPoolDomain.domainName}.auth.${
        Stack.of(this).region
      }.amazoncognito.com`,
    });

    new CfnOutput(this, `${famHelpDesk}-IdentityPoolId-${stage}`, {
      value: this.identityPool.ref,
    });

    new CfnOutput(this, `${famHelpDesk}-UserPoolArn-${stage}`, {
      value: this.userPool.userPoolArn,
      exportName: `${famHelpDesk}-AuthStack-UserPoolArn-${stage}`,
    });
  }
}
