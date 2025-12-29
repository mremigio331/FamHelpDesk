import React from "react";
import { Form } from "antd";
import { useNavigate } from "react-router-dom";
import { useMobileDetection } from "../../provider/MobileDetectionProvider";
import useUpdateUserProfile from "../../hooks/user/useUpdateUserProfile";
import useGetUserProfile from "../../hooks/user/useGetUserProfile";
import EditProfileDesktop from "./EditProfileDesktop";
import EditProfileMobile from "./EditProfileMobile";

const EditProfile = () => {
  const navigate = useNavigate();
  const [form] = Form.useForm();
  const { isMobile } = useMobileDetection();
  const { userProfile, isUserFetching } = useGetUserProfile();
  const {
    updateProfileAsync,
    isUpdating,
    isUpdateError,
    updateError,
    isUpdateSuccess,
  } = useUpdateUserProfile();

  const props = {
    navigate,
    form,
    userProfile,
    isUserFetching,
    updateProfileAsync,
    isUpdating,
    isUpdateError,
    updateError,
    isUpdateSuccess,
  };

  return isMobile ? (
    <EditProfileMobile {...props} />
  ) : (
    <EditProfileDesktop {...props} />
  );
};

export default EditProfile;
