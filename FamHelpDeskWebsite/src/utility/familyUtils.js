/**
 * Get membership status for a family
 * @param {string} familyId - The family ID to check
 * @param {Object} myFamilies - Object mapping family IDs to family data with membership
 * @returns {Object|null} - The membership object or null if not a member
 */
export const getMembershipForFamily = (familyId, myFamilies) => {
  const familyData = myFamilies[familyId];
  return familyData ? familyData.membership : null;
};

/**
 * Check if user is an actual member (not pending or declined)
 * @param {string} familyId - The family ID to check
 * @param {Object} myFamilies - Object mapping family IDs to family data with membership
 * @returns {boolean} - True if user is a MEMBER
 */
export const isActualMember = (familyId, myFamilies) => {
  const membership = getMembershipForFamily(familyId, myFamilies);
  return membership ? membership.status === "MEMBER" : false;
};

/**
 * Check if user has a pending membership request
 * @param {string} familyId - The family ID to check
 * @param {Object} myFamilies - Object mapping family IDs to family data with membership
 * @returns {boolean} - True if membership status is AWAITING
 */
export const hasPendingRequest = (familyId, myFamilies) => {
  const membership = getMembershipForFamily(familyId, myFamilies);
  return membership ? membership.status === "AWAITING" : false;
};

/**
 * Check if user's membership was declined
 * @param {string} familyId - The family ID to check
 * @param {Object} myFamilies - Object mapping family IDs to family data with membership
 * @returns {boolean} - True if membership status is DECLINED
 */
export const wasDeclined = (familyId, myFamilies) => {
  const membership = getMembershipForFamily(familyId, myFamilies);
  return membership ? membership.status === "DECLINED" : false;
};

/**
 * Get the membership status string
 * @param {string} familyId - The family ID to check
 * @param {Object} myFamilies - Object mapping family IDs to family data with membership
 * @returns {string|null} - "MEMBER", "AWAITING", "DECLINED", or null
 */
export const getMembershipStatus = (familyId, myFamilies) => {
  const membership = getMembershipForFamily(familyId, myFamilies);
  return membership ? membership.status : null;
};
