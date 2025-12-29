import React, { useContext } from "react";
import { useNavigate } from "react-router-dom";
import { UserAuthenticationContext } from "../../provider/UserAuthenticationProvider";
import { useMobileDetection } from "../../provider/MobileDetectionProvider";
import useGetUserProfile from "../../hooks/user/useGetUserProfile";
import UserProfileDesktop from "./UserProfileDesktop";
import UserProfileMobile from "./UserProfileMobile";

const UserProfile = () => {
  const navigate = useNavigate();
  const { logoutUser } = useContext(UserAuthenticationContext);
  const { isMobile } = useMobileDetection();
  const { userProfile, isUserFetching, isUserError, userError, userRefetch } =
    useGetUserProfile();

  const props = {
    navigate,
    logoutUser,
    userProfile,
    isUserFetching,
    isUserError,
    userError,
    userRefetch,
  };

  return isMobile ? (
    <UserProfileMobile {...props} />
  ) : (
    <UserProfileDesktop {...props} />
  );
};

export default UserProfile;
