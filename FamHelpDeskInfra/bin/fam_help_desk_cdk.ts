#!/usr/bin/env node
import * as cdk from "aws-cdk-lib";
import { famHelpDesk } from "../lib/constants";
import { DatabaseStack } from "../lib/stacks/database-stack";
import { CognitoStack } from "../lib/stacks/cognito-stack";
import { ApiStack } from "../lib/stacks/api-stack";
import { WebsiteStack } from "../lib/stacks/website-stack";
import * as fs from "fs";
import * as path from "path";

async function getEnvConfig() {
  // Use environment variables for config in CI/CD, fallback to file for local dev
  const isCICD =
    !!process.env.CICD ||
    !!process.env.CODEBUILD_BUILD_ID ||
    !!process.env.CODEPIPELINE_EXECUTION_ID ||
    !!process.env.CODEDEPLOY_DEPLOYMENT_ID ||
    !!process.env.USE_SECRETS_MANAGER;
  
  try {
    if (isCICD) {
      // Expect a single environment variable CDK_ENV_CONFIG containing the JSON config
      if (!process.env.CDK_ENV_CONFIG) {
        throw new Error(
          "CDK_ENV_CONFIG environment variable not set in CI/CD environment",
        );
      }
      return JSON.parse(process.env.CDK_ENV_CONFIG);
    } else {
      // Local fallback
      const envFilePath = path.resolve(__dirname, "../cdk.env.json");
      console.log(`[CDK ENV DETECT] Using local env file: ${envFilePath}`);
      
      if (!fs.existsSync(envFilePath)) {
        throw new Error(
          `Environment configuration file not found: ${envFilePath}. Please ensure cdk.env.json exists.`
        );
      }
      
      const envFileContent = fs.readFileSync(envFilePath, "utf-8");
      return JSON.parse(envFileContent);
    }
  } catch (error) {
    if (error instanceof SyntaxError) {
      throw new Error(
        `Invalid JSON in environment configuration: ${error.message}`
      );
    }
    throw error;
  }
}

async function main() {
  const app = new cdk.App();
  const awsEnv = { region: "us-west-2" };
  const envConfig = await getEnvConfig();

  for (const stage of Object.keys(envConfig)) {
    const config = envConfig[stage];

    const {
      hostedZoneId,
      websiteDomainName,
      apiDomainName,
      callbackUrls,
      wildcardCertificateArn,
      apiWildcardCertificateArn,
      escalationEmail,
      escalationNumber,
      googleOathKeys,
    } = config;

    const databaseStack = new DatabaseStack(
      app,
      `${famHelpDesk}-DatabaseStack-${stage}`,
      {
        env: awsEnv,
        stage,
      },
    );

    const cognitoStack = new CognitoStack(
      app,
      `${famHelpDesk}-CognitoStack-${stage}`,
      {
        env: awsEnv,
        stage,
        callbackUrls,
        userTable: databaseStack.table,
        escalationEmail,
        escalationNumber,
        googleOathKeys,
      },
    );

    new ApiStack(app, `${famHelpDesk}-ApiStack-${stage}`, {
      env: awsEnv,
      apiDomainName: apiDomainName,
      rootDomainName: websiteDomainName,
      certificateArn: apiWildcardCertificateArn,
      hostedZoneId: hostedZoneId,
      stage,
      userPool: cognitoStack.userPool,
      userPoolClient: cognitoStack.userPoolClient,
      userPoolClientIOS: cognitoStack.userPoolClientIOS,
      userTable: databaseStack.table,
      escalationEmail: escalationEmail,
      escalationNumber: escalationNumber,
    });

    new WebsiteStack(app, `${famHelpDesk}-WebsiteStack-${stage}`, {
      env: awsEnv,
      websiteDomainName: websiteDomainName,
      rootDomainName: websiteDomainName,
      certificateArn: wildcardCertificateArn,
      hostedZoneId: hostedZoneId,
      stage,
    });
  }
}

main();
