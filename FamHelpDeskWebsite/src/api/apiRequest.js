import axios from "axios";

const getHeaders = (accessToken) => {
  return {
    "Content-Type": "application/json",
    ...(accessToken && { Authorization: `Bearer ${accessToken}` }),
  };
};

export const apiRequestGet = (apiEndpoint, route, accessToken) => {
  return axios.get(encodeURI(`${apiEndpoint}${route}`), {
    headers: getHeaders(accessToken),
  });
};

export const apiRequestPost = ({ apiEndpoint, accessToken, body }) => {
  return axios.post(apiEndpoint, body, {
    withCredentials: true,
    headers: getHeaders(accessToken),
  });
};

export const apiRequestPut = ({ apiEndpoint, accessToken, body }) => {
  return axios.put(apiEndpoint, body, {
    withCredentials: true,
    headers: getHeaders(accessToken),
  });
};

export const apiRequestDelete = ({ apiEndpoint, accessToken }) => {
  return axios.delete(apiEndpoint, {
    withCredentials: true,
    headers: getHeaders(accessToken),
  });
};
