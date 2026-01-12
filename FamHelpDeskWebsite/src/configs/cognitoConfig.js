import {
  PROD_WEBSITE_ENDPOINT,
  STAGING_WEBSITE_ENDPOINT,
} from "../constants/endpoints";

// Based on iOS AuthConfig.swift
const STAGING_USER_POOL_ID = "us-west-2_4hHBH4CPn";
const STAGING_CLIENT_ID = "1omenujjf07khboa3ggtdujh63";
const STAGING_REGION = "us-west-2";
const STAGING_COGNITO_DOMAIN = "famhelpdesk-testing";

const PROD_USER_POOL_ID = "us-west-2_KgiY8aKBk";
const PROD_CLIENT_ID = "21rh7k5v6nbrihub67b102vdir";
const PROD_REGION = "us-west-2";
const PROD_COGNITO_DOMAIN = "famhelpdesk-prod";

export const COGNITO_CONSTANTS = {
  DEV: {
    clientId: STAGING_CLIENT_ID,
    domain: STAGING_COGNITO_DOMAIN,
    redirectUri: "http://localhost:8080/",
    region: STAGING_REGION,
    userPoolId: STAGING_USER_POOL_ID,
  },
  STAGING: {
    clientId: STAGING_CLIENT_ID,
    domain: STAGING_COGNITO_DOMAIN,
    redirectUri: `${STAGING_WEBSITE_ENDPOINT}/`,
    region: STAGING_REGION,
    userPoolId: STAGING_USER_POOL_ID,
  },
  PROD: {
    clientId: PROD_CLIENT_ID,
    domain: PROD_COGNITO_DOMAIN,
    redirectUri: `${PROD_WEBSITE_ENDPOINT}/`,
    region: PROD_REGION,
    userPoolId: PROD_USER_POOL_ID,
  },
};
