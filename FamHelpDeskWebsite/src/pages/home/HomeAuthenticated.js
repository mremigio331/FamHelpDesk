import React from "react";
import { Typography, Spin, Alert } from "antd";
import useGetUserProfile from "../../hooks/user/useGetUserProfile";

const { Title, Text } = Typography;

const HomeAuthenticated = () => {
  const { userProfile, isUserFetching, isUserError, userError } =
    useGetUserProfile();

  if (isUserFetching) {
    return (
      <div style={{ padding: "50px", textAlign: "center" }}>
        <Spin size="large" />
      </div>
    );
  }

  if (isUserError) {
    return (
      <div style={{ padding: "50px", maxWidth: "600px", margin: "0 auto" }}>
        <Alert
          message="Error"
          description={userError?.message || "Failed to load profile"}
          type="error"
          showIcon
        />
      </div>
    );
  }

  return (
    <div style={{ padding: "50px" }}>
      <div style={{ textAlign: "center", maxWidth: "600px", margin: "0 auto" }}>
        <Title level={2}>Welcome to Fam Help Desk</Title>
        {userProfile && (
          <div style={{ marginTop: "20px", marginBottom: "20px" }}>
            <Text style={{ fontSize: "18px" }}>
              Hello, <strong>{userProfile.display_name}</strong>!
            </Text>
          </div>
        )}
        <div style={{ marginTop: "30px" }}>
          <Text>
            You are now signed in to the Fam Help Desk. Support features will be
            added here soon.
          </Text>
        </div>
      </div>
    </div>
  );
};

export default HomeAuthenticated;
