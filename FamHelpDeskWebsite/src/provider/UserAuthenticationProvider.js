import React, { createContext, useReducer, useEffect, useMemo } from "react";
import getStage from "../utility/getStage";
import { jwtDecode } from "jwt-decode";
import Cookies from "js-cookie";
import { COGNITO_CONSTANTS } from "../configs/cognitoConfig";
import { DEV } from "../constants/stages";

export const UserAuthenticationContext = createContext();

const initialState = {
  isAuthenticated: null,
  idToken: null,
  accessToken: null,
};

const userReducer = (state, action) => {
  switch (action.type) {
    case "SET_AUTH":
      return {
        ...state,
        isAuthenticated: true,
        idToken: action.payload.idToken,
        accessToken: action.payload.accessToken,
      };
    case "LOGOUT":
      return { ...initialState, isAuthenticated: false };
    default:
      return state;
  }
};

const UserAuthenticationProvider = ({ children }) => {
  const [state, dispatch] = useReducer(userReducer, initialState);

  const stage = getStage();
  const stageUpper = stage.toUpperCase();
  const cognitoConfig = COGNITO_CONSTANTS[stageUpper];

  const cognitoDomain = cognitoConfig.domain;
  const clientId = cognitoConfig.clientId;
  const redirectUri = cognitoConfig.redirectUri;
  const region = cognitoConfig.region;
  const responseType = "code";

  if (!cognitoDomain || !clientId || !redirectUri || !region) {
    throw new Error("Missing required Cognito configuration");
  }

  const constructHostedUIUrl = (path) => {
    return `https://${cognitoDomain}.auth.${region}.amazoncognito.com/${path}?response_type=${responseType}&client_id=${clientId}&redirect_uri=${encodeURIComponent(redirectUri)}`;
  };

  const initiateSignIn = () => {
    const hostedUIUrl = constructHostedUIUrl("login");
    window.location.assign(hostedUIUrl);
  };

  const initiateSignUp = () => {
    const hostedUIUrl = constructHostedUIUrl("signup");
    window.location.assign(hostedUIUrl);
  };

  const logoutUser = () => {
    const hostedLogoutUrl = `https://${cognitoDomain}.auth.${region}.amazoncognito.com/logout?client_id=${clientId}&logout_uri=${encodeURIComponent(redirectUri)}`;
    dispatch({ type: "LOGOUT" });
    Cookies.remove("idToken");
    Cookies.remove("accessToken");
    window.location.assign(hostedLogoutUrl);
  };

  const fetchUserSession = async () => {
    const urlParams = new URLSearchParams(window.location.search);
    const authorizationCode = urlParams.get("code");

    if (authorizationCode) {
      const tokenUrl = `https://${cognitoDomain}.auth.${region}.amazoncognito.com/oauth2/token`;
      const body = new URLSearchParams({
        grant_type: "authorization_code",
        client_id: clientId,
        code: authorizationCode,
        redirect_uri: redirectUri,
      });

      try {
        const response = await fetch(tokenUrl, {
          method: "POST",
          headers: {
            "Content-Type": "application/x-www-form-urlencoded",
          },
          body: body.toString(),
        });

        if (!response.ok) {
          throw new Error("Failed to fetch tokens");
        }

        const data = await response.json();
        Cookies.set("idToken", data.id_token, {
          secure: true,
          sameSite: "Strict",
        });
        Cookies.set("accessToken", data.access_token, {
          secure: true,
          sameSite: "Strict",
        });

        dispatch({
          type: "SET_AUTH",
          payload: {
            idToken: data.id_token,
            accessToken: data.access_token,
          },
        });

        // Remove the code param from the URL after successful login
        const url = new URL(window.location.href);
        url.searchParams.delete("code");
        window.history.replaceState(
          {},
          document.title,
          url.pathname + url.search,
        );
      } catch (error) {
        if (stage === DEV) {
          console.error("Error fetching user session:", error);
        }
      }
    }
  };

  const isTokenExpired = (token) => {
    try {
      const { exp } = jwtDecode(token);
      return Date.now() >= exp * 1000;
    } catch {
      return true;
    }
  };

  const loadUserSessionFromCookies = () => {
    const idToken = Cookies.get("idToken");
    const accessToken = Cookies.get("accessToken");
    if (idToken && accessToken && !isTokenExpired(accessToken)) {
      dispatch({
        type: "SET_AUTH",
        payload: {
          idToken,
          accessToken,
        },
      });
    } else {
      Cookies.remove("idToken");
      Cookies.remove("accessToken");
    }
  };

  useEffect(() => {
    loadUserSessionFromCookies();
    fetchUserSession();
    // eslint-disable-next-line
  }, []);

  const contextValue = useMemo(
    () => ({
      isAuthenticated: state.isAuthenticated,
      idToken: state.idToken,
      accessToken: state.accessToken,
      initiateSignIn,
      initiateSignUp,
      logoutUser,
    }),
    [
      state.isAuthenticated,
      state.idToken,
      state.accessToken,
      initiateSignIn,
      initiateSignUp,
      logoutUser,
    ],
  );

  return (
    <UserAuthenticationContext.Provider value={contextValue}>
      {children}
    </UserAuthenticationContext.Provider>
  );
};

export default UserAuthenticationProvider;
