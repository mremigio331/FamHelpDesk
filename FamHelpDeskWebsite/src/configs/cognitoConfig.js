import {
  PROD_WEBSITE_ENDPOINT,
  TESTING_WEBSITE_ENDPOINT,
} from "../constants/endpoints";

// Based on iOS AuthConfig.swift
const TESTING_USER_POOL_ID = "us-west-2_gGJC3MdJM";
const TESTING_CLIENT_ID = "a6mdrnft8uqqcuddv95bma3hb";
const TESTING_REGION = "us-west-2";
const TESTING_COGNITO_DOMAIN = "famhelpdesk-testing";

const PROD_USER_POOL_ID = "us-west-2_rTifqszW9";
const PROD_CLIENT_ID = "2p0om4iln5hr68r03memqhfl41";
const PROD_REGION = "us-west-2";
const PROD_COGNITO_DOMAIN = "famhelpdesk-prod";

export const COGNITO_CONSTANTS = {
  DEV: {
    clientId: TESTING_CLIENT_ID,
    domain: TESTING_COGNITO_DOMAIN,
    redirectUri: "http://localhost:8080/",
    region: TESTING_REGION,
    userPoolId: TESTING_USER_POOL_ID,
  },
  TESTING: {
    clientId: TESTING_CLIENT_ID,
    domain: TESTING_COGNITO_DOMAIN,
    redirectUri: `${TESTING_WEBSITE_ENDPOINT}/`,
    region: TESTING_REGION,
    userPoolId: TESTING_USER_POOL_ID,
  },
  PROD: {
    clientId: PROD_CLIENT_ID,
    domain: PROD_COGNITO_DOMAIN,
    redirectUri: `${PROD_WEBSITE_ENDPOINT}/`,
    region: PROD_REGION,
    userPoolId: PROD_USER_POOL_ID,
  },
};
