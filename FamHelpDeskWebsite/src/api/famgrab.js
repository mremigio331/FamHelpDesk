import { apiRequestGet, apiRequestPost } from "./apiRequest";

// Balance
export const getBalance = (apiEndpoint, familyId, accessToken) => {
  return apiRequestGet(
    apiEndpoint,
    `/family/${familyId}/grab/balance`,
    accessToken,
  );
};

// Requests
export const createRequest = (apiEndpoint, familyId, accessToken, body) => {
  return apiRequestPost({
    apiEndpoint: `${apiEndpoint}/family/${familyId}/grab/requests`,
    accessToken,
    body,
  });
};

export const listRequests = (apiEndpoint, familyId, accessToken, params) => {
  const queryParams = new URLSearchParams();
  if (params?.status) queryParams.append("status", params.status);
  if (params?.user_role) queryParams.append("user_role", params.user_role);
  if (params?.start_date) queryParams.append("start_date", params.start_date);
  if (params?.end_date) queryParams.append("end_date", params.end_date);
  if (params?.limit) queryParams.append("limit", params.limit);
  if (params?.last_key) queryParams.append("last_key", params.last_key);

  const queryString = queryParams.toString();
  const route = `/family/${familyId}/grab/requests${queryString ? `?${queryString}` : ""}`;
  return apiRequestGet(apiEndpoint, route, accessToken);
};

export const getRequest = (apiEndpoint, familyId, requestId, accessToken) => {
  return apiRequestGet(
    apiEndpoint,
    `/family/${familyId}/grab/requests/${requestId}`,
    accessToken,
  );
};

// Lifecycle actions
export const claimRequest = (apiEndpoint, familyId, requestId, accessToken) => {
  return apiRequestPost({
    apiEndpoint: `${apiEndpoint}/family/${familyId}/grab/requests/${requestId}/claim`,
    accessToken,
    body: {},
  });
};

export const completeRequest = (
  apiEndpoint,
  familyId,
  requestId,
  accessToken,
  body,
) => {
  return apiRequestPost({
    apiEndpoint: `${apiEndpoint}/family/${familyId}/grab/requests/${requestId}/complete`,
    accessToken,
    body: body || {},
  });
};

export const confirmRequest = (
  apiEndpoint,
  familyId,
  requestId,
  accessToken,
  body,
) => {
  return apiRequestPost({
    apiEndpoint: `${apiEndpoint}/family/${familyId}/grab/requests/${requestId}/confirm`,
    accessToken,
    body: body || {},
  });
};

export const cancelRequest = (
  apiEndpoint,
  familyId,
  requestId,
  accessToken,
) => {
  return apiRequestPost({
    apiEndpoint: `${apiEndpoint}/family/${familyId}/grab/requests/${requestId}/cancel`,
    accessToken,
    body: {},
  });
};

// Item-level lifecycle actions
export const claimItems = (apiEndpoint, familyId, requestId, accessToken, body) => {
  return apiRequestPost({
    apiEndpoint: `${apiEndpoint}/family/${familyId}/grab/requests/${requestId}/claim-items`,
    accessToken,
    body,
  });
};

export const completeItems = (apiEndpoint, familyId, requestId, accessToken, body) => {
  return apiRequestPost({
    apiEndpoint: `${apiEndpoint}/family/${familyId}/grab/requests/${requestId}/complete-items`,
    accessToken,
    body,
  });
};

export const confirmItems = (apiEndpoint, familyId, requestId, accessToken, body) => {
  return apiRequestPost({
    apiEndpoint: `${apiEndpoint}/family/${familyId}/grab/requests/${requestId}/confirm-items`,
    accessToken,
    body,
  });
};

export const cancelItems = (apiEndpoint, familyId, requestId, accessToken, body) => {
  return apiRequestPost({
    apiEndpoint: `${apiEndpoint}/family/${familyId}/grab/requests/${requestId}/cancel-items`,
    accessToken,
    body,
  });
};

// Photo
export const getUploadUrl = (
  apiEndpoint,
  familyId,
  requestId,
  accessToken,
  body,
) => {
  return apiRequestPost({
    apiEndpoint: `${apiEndpoint}/family/${familyId}/grab/requests/${requestId}/photo/upload-url`,
    accessToken,
    body: body || {},
  });
};

export const getPhotoUrl = (
  apiEndpoint,
  familyId,
  requestId,
  accessToken,
) => {
  return apiRequestGet(
    apiEndpoint,
    `/family/${familyId}/grab/requests/${requestId}/photo`,
    accessToken,
  );
};

// Leaderboard
export const getLeaderboard = (apiEndpoint, familyId, accessToken) => {
  return apiRequestGet(
    apiEndpoint,
    `/family/${familyId}/grab/leaderboard`,
    accessToken,
  );
};

// Review History
export const getReviewHistory = (apiEndpoint, familyId, userId, accessToken, params) => {
  const queryParams = new URLSearchParams();
  if (params?.limit) queryParams.append("limit", params.limit);
  if (params?.last_key) queryParams.append("last_key", params.last_key);

  const queryString = queryParams.toString();
  const route = `/family/${familyId}/grab/reviews/${userId}${queryString ? `?${queryString}` : ""}`;
  return apiRequestGet(apiEndpoint, route, accessToken);
};

// Transactions
export const getTransactions = (
  apiEndpoint,
  familyId,
  accessToken,
  params,
) => {
  const queryParams = new URLSearchParams();
  if (params?.limit) queryParams.append("limit", params.limit);
  if (params?.last_key) queryParams.append("last_key", params.last_key);

  const queryString = queryParams.toString();
  const route = `/family/${familyId}/grab/transactions${queryString ? `?${queryString}` : ""}`;
  return apiRequestGet(apiEndpoint, route, accessToken);
};
