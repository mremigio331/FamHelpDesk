import {
  Stack,
  StackProps,
  Duration,
  aws_logs as logs,
  aws_apigateway as apigw,
  aws_lambda as lambda,
  aws_cognito as cognito,
  aws_dynamodb as dynamodb,
  aws_route53 as route53,
  aws_certificatemanager as acm,
  aws_route53_targets as targets,
} from "aws-cdk-lib";
import * as iam from "aws-cdk-lib/aws-iam";
import { Construct } from "constructs";
import * as path from "path";
import { addApiMonitoring } from "../monitoring/api-monitoring";
import { famHelpDesk } from "../constants";

interface ApiStackProps extends StackProps {
  apiDomainName: string;
  rootDomainName: string;
  certificateArn: string;
  hostedZoneId: string;
  userPool: cognito.UserPool;
  userPoolClient: cognito.UserPoolClient;
  userPoolClientIOS: cognito.UserPoolClient;
  stage: string;
  userTable: dynamodb.ITable;
  escalationEmail: string;
  escalationNumber: string;
}

export class ApiStack extends Stack {
  public readonly api: apigw.LambdaRestApi;
  public readonly identityPool: cognito.CfnIdentityPool;

  constructor(scope: Construct, id: string, props: ApiStackProps) {
    super(scope, id, props);

    const {
      apiDomainName,
      rootDomainName,
      certificateArn,
      hostedZoneId,
      userPool,
      userPoolClient,
      userPoolClientIOS,
      userTable,
      stage,
      escalationEmail,
      escalationNumber,
    } = props;

    const apiGwLogsRole = new iam.Role(
      this,
      `${famHelpDesk}-ApiGatewayCloudWatchRole-${stage}`,
      {
        assumedBy: new iam.ServicePrincipal("apigateway.amazonaws.com"),
        inlinePolicies: {
          ApiGwCloudWatchLogsPolicy: new iam.PolicyDocument({
            statements: [
              new iam.PolicyStatement({
                effect: iam.Effect.ALLOW,
                actions: [
                  "logs:CreateLogGroup",
                  "logs:CreateLogStream",
                  "logs:DescribeLogGroups",
                  "logs:DescribeLogStreams",
                  "logs:PutLogEvents",
                ],
                resources: ["*"],
              }),
            ],
          }),
        },
      },
    );

    new apigw.CfnAccount(this, `${famHelpDesk}-ApiGatewayAccount-${stage}`, {
      cloudWatchRoleArn: apiGwLogsRole.roleArn,
    });

    const layer = new lambda.LayerVersion(
      this,
      `${famHelpDesk}-ApiLayer-${stage}`,
      {
        code: lambda.Code.fromAsset(
          path.join(__dirname, "../../../FamHelpDeskBackend/lambda_layer.zip"),
        ),
        compatibleRuntimes: [lambda.Runtime.PYTHON_3_11],
        description: `${famHelpDesk}-ApiLayer-${stage}`,
      },
    );

    const applicationLogsLogGroup = new logs.LogGroup(
      this,
      `${famHelpDesk}-ApplicationLogs-${stage}`,
      {
        logGroupName: `/aws/lambda/${famHelpDesk}-ApiLambda-${stage}`,
        retention: logs.RetentionDays.INFINITE,
      },
    );

    const famHelpDeskApi = new lambda.Function(
      this,
      `${famHelpDesk}-ApiLambda-${stage}`,
      {
        functionName: `${famHelpDesk}-ApiLambda-${stage}`,
        runtime: lambda.Runtime.PYTHON_3_11,
        handler: "app.handler",
        code: lambda.Code.fromAsset(
          path.join(__dirname, "../../../FamHelpDeskBackend"),
        ),
        timeout: Duration.seconds(30),
        memorySize: 1024,
        layers: [layer],
        logGroup: applicationLogsLogGroup,
        tracing: lambda.Tracing.ACTIVE,
        description: `${famHelpDesk}-ApiLambda-${stage}`,
        environment: {
          TABLE_NAME: userTable.tableName,
          COGNITO_USER_POOL_ID: userPool.userPoolId,
          COGNITO_CLIENT_ID: userPoolClient.userPoolClientId,
          COGNITO_API_REDIRECT_URI: `https://${apiDomainName}/`,
          COGNITO_REGION: "us-west-2",
          COGNITO_DOMAIN:
            stage.toLowerCase() === "prod"
              ? "https://famhelpdesk.auth.us-west-2.amazoncognito.com"
              : `https://famhelpdesk-${stage.toLowerCase()}.auth.us-west-2.amazoncognito.com`,
          STAGE: stage.toLowerCase(),
          API_DOMAIN_NAME: apiDomainName,
        },
      },
    );

    famHelpDeskApi.addToRolePolicy(
      new iam.PolicyStatement({
        effect: iam.Effect.ALLOW,
        actions: ["cloudwatch:PutMetricData"],
        resources: ["*"],
      }),
    );

    famHelpDeskApi.addToRolePolicy(
      new iam.PolicyStatement({
        effect: iam.Effect.ALLOW,
        actions: ["cognito-idp:AdminUpdateUserAttributes"],
        resources: [userPool.userPoolArn],
      }),
    );

    userTable.grantReadWriteData(famHelpDeskApi);

    const accessLogGroup = new logs.LogGroup(
      this,
      `${famHelpDesk}-ServiceLogs-${stage}`,
      {
        logGroupName: `/aws/apigateway/${famHelpDesk}-ServiceLogs-${stage}`,
        retention: logs.RetentionDays.INFINITE,
      },
    );

    this.identityPool = new cognito.CfnIdentityPool(
      this,
      `${famHelpDesk}-IdentityPool-${stage}`,
      {
        allowUnauthenticatedIdentities: false,
        cognitoIdentityProviders: [
          {
            clientId: userPoolClient.userPoolClientId,
            providerName: userPool.userPoolProviderName,
          },
          {
            clientId: userPoolClientIOS.userPoolClientId,
            providerName: userPool.userPoolProviderName,
          },
        ],
      },
    );

    const authorizer = new apigw.CognitoUserPoolsAuthorizer(
      this,
      `${famHelpDesk}-ApiAuthorizer-${stage}`,
      {
        cognitoUserPools: [userPool],
        authorizerName: `${famHelpDesk}-ApiAuthorizer-${stage}`,
        identitySource: "method.request.header.Authorization",
      },
    );

    this.api = new apigw.LambdaRestApi(
      this,
      `${famHelpDesk}-LambdaRestApi-${stage}`,
      {
        handler: famHelpDeskApi,
        restApiName: `${famHelpDesk}-Api-${stage}`,
        proxy: false,
        defaultMethodOptions: {
          authorizationType: apigw.AuthorizationType.COGNITO,
          authorizer,
        },
        defaultCorsPreflightOptions: {
          allowOrigins:
            stage.toLowerCase() === "prod"
              ? ["https://famhelpdesk.com"]
              : stage.toLowerCase() === "testing"
              ? ["https://testing.famhelpdesk.com", "http://localhost:8080"]
              : ["http://localhost:8080"],
          allowMethods: apigw.Cors.ALL_METHODS,
          allowHeaders: ["authorization", "content-type", "X-Git-Commit"],
          allowCredentials: true,
        },
        deployOptions: {
          tracingEnabled: true,
          accessLogDestination: new apigw.LogGroupLogDestination(
            accessLogGroup,
          ),
          accessLogFormat: apigw.AccessLogFormat.custom(
            JSON.stringify({
              requestId: "$context.requestId",
              user_id: "$context.authorizer.claims.sub",
              email: "$context.authorizer.claims.email",
              name: "$context.authorizer.claims.name",
              resourcePath: "$context.path",
              httpMethod: "$context.httpMethod",
              ip: "$context.identity.sourceIp",
              status: "$context.status",
              errorMessage: "$context.error.message",
              errorResponseType: "$context.error.responseType",
              auth_raw: "$context.authorizer",
              xrayTraceId: "$context.xrayTraceId",
              websiteVersion:
                "$context.requestOverride.header.X-Git-Commit ?? 'unknown'",
            }),
          ),
          loggingLevel: apigw.MethodLoggingLevel.INFO,
          dataTraceEnabled: true,
          description: `${famHelpDesk}-ApiGateway-Deployment-${stage}`,
        },
      },
    );

    const docsResource = this.api.root.addResource("docs");
    docsResource.addMethod("GET", new apigw.LambdaIntegration(famHelpDeskApi), {
      authorizationType: apigw.AuthorizationType.NONE,
    });

    // Allow unauthenticated access to /docs/{proxy+} (static assets)
    const docsProxyResource = docsResource.addResource("{proxy+}");
    docsProxyResource.addMethod(
      "ANY",
      new apigw.LambdaIntegration(famHelpDeskApi),
      {
        authorizationType: apigw.AuthorizationType.NONE,
      },
    );

    const openapiResource = this.api.root.addResource("openapi.json");
    openapiResource.addMethod(
      "GET",
      new apigw.LambdaIntegration(famHelpDeskApi),
      {
        authorizationType: apigw.AuthorizationType.NONE,
      },
    );

    const proxyResource = this.api.root.addResource("{proxy+}");
    proxyResource.addMethod(
      "ANY",
      new apigw.LambdaIntegration(famHelpDeskApi),
      {
        authorizationType: apigw.AuthorizationType.COGNITO,
        authorizer,
      },
    );

    // Add API monitoring
    addApiMonitoring(this, this.api, stage, escalationEmail, escalationNumber);

    // DNS Configuration - Combined from ApiDnsStack
    const hostedZone = route53.HostedZone.fromHostedZoneAttributes(
      this,
      `${famHelpDesk}-ApiHostedZone-${stage}`,
      {
        hostedZoneId,
        zoneName: rootDomainName,
      },
    );

    const certificate = acm.Certificate.fromCertificateArn(
      this,
      `${famHelpDesk}-ImportedApiCert-${stage}`,
      certificateArn,
    );

    const customDomain = new apigw.DomainName(
      this,
      `${famHelpDesk}-ApiCustomDomain-${stage}`,
      {
        domainName: apiDomainName,
        certificate: certificate!,
        endpointType: apigw.EndpointType.REGIONAL,
      },
    );

    new apigw.BasePathMapping(
      this,
      `${famHelpDesk}-ApiBasePathMapping-${stage}`,
      {
        domainName: customDomain,
        restApi: this.api,
      },
    );

    new route53.ARecord(this, `${famHelpDesk}-ApiAliasRecord-${stage}`, {
      recordName: "api",
      zone: hostedZone,
      target: route53.RecordTarget.fromAlias(
        new targets.ApiGatewayDomain(customDomain),
      ),
    });
  }
}
