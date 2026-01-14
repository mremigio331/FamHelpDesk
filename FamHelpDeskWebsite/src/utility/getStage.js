import { TESTING, PROD, DEV } from "../constants/stages";

const getStage = () => {
  const domain = window.location.hostname.trim();

  if (domain === "testing.famhelpdesk.com") {
    console.log(`Stage ${TESTING}`);
    return TESTING;
  } else if (domain === "famhelpdesk.com") {
    console.log(`Stage: ${PROD}`);
    return PROD;
  }

  console.log(`Stage: ${DEV}`);
  return DEV;
};

export default getStage;
