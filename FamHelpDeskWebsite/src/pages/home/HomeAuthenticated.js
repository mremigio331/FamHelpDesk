import React from "react";
import { Typography, Spin, Alert } from "antd";
import { useNavigate } from "react-router-dom";
import useGetUserProfile from "../../hooks/user/useGetUserProfile";
import MyFamiliesCard from "../../components/family/MyFamiliesCard";
import { useMyFamilies } from "../../provider/MyFamiliesProvider";

const { Title, Text } = Typography;

const HomeAuthenticated = () => {
  const navigate = useNavigate();
  const { userProfile, isUserFetching, isUserError, userError } =
    useGetUserProfile();
  const { isMyFamiliesFetching } = useMyFamilies();

  if (isUserFetching || isMyFamiliesFetching) {
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
    <div style={{ padding: "50px", maxWidth: "1200px", margin: "0 auto" }}>
      <div style={{ textAlign: "center", marginBottom: "40px" }}>
        <Title level={2}>Welcome to Fam Help Desk</Title>
        {userProfile && (
          <div style={{ marginTop: "20px", marginBottom: "20px" }}>
            <Text style={{ fontSize: "18px" }}>
              Hello, <strong>{userProfile.display_name}</strong>!
            </Text>
          </div>
        )}
      </div>

      <MyFamiliesCard />
    </div>
  );
};

export default HomeAuthenticated;
