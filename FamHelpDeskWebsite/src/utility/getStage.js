import { STAGING, PROD, DEV } from "../constants/stages";

const getStage = () => {
  const domain = window.location.hostname.trim();

  if (domain === "staging.famhelpdesk.com") {
    return STAGING;
  } else if (domain === "famhelpdesk.com") {
    return PROD;
  }

  return DEV;
};

export default getStage;
