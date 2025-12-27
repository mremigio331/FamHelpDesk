import React, { useContext } from "react";
import {
  Card,
  Descriptions,
  Button,
  Spin,
  Alert,
  Space,
  Typography,
} from "antd";
import {
  UserOutlined,
  ReloadOutlined,
  LogoutOutlined,
  ArrowLeftOutlined,
  EditOutlined,
} from "@ant-design/icons";
import { useNavigate } from "react-router-dom";
import { UserAuthenticationContext } from "../../provider/UserAuthenticationProvider";
import useGetUserProfile from "../../hooks/user/useGetUserProfile";

const { Title } = Typography;

const UserProfile = () => {
  const navigate = useNavigate();
  const { logoutUser } = useContext(UserAuthenticationContext);
  const { userProfile, isUserFetching, isUserError, userError, userRefetch } =
    useGetUserProfile();

  const handleSignOut = () => {
    logoutUser();
  };

  const handleRefresh = () => {
    userRefetch();
  };

  return (
    <div style={{ padding: "50px", maxWidth: "800px", margin: "0 auto" }}>
      <Space direction="vertical" size="large" style={{ width: "100%" }}>
        <div>
          <Button
            type="link"
            icon={<ArrowLeftOutlined />}
            onClick={() => navigate("/")}
            style={{ paddingLeft: 0 }}
          >
            Back to Home
          </Button>
        </div>

        <Card>
          <div
            style={{
              display: "flex",
              alignItems: "center",
              gap: "12px",
              marginBottom: "24px",
            }}
          >
            <UserOutlined style={{ fontSize: "24px" }} />
            <Title level={2} style={{ margin: 0 }}>
              User Profile
            </Title>
          </div>

          {isUserFetching ? (
            <div style={{ textAlign: "center", padding: "40px" }}>
              <Spin size="large" />
            </div>
          ) : isUserError ? (
            <Alert
              message="Error"
              description={userError?.message || "Failed to load profile"}
              type="error"
              showIcon
              style={{ marginBottom: "20px" }}
            />
          ) : userProfile ? (
            <>
              <Descriptions
                bordered
                column={1}
                size="middle"
                style={{ marginBottom: "24px" }}
              >
                <Descriptions.Item label="Display Name">
                  {userProfile.display_name}
                </Descriptions.Item>
                <Descriptions.Item label="Nickname">
                  {userProfile.nick_name}
                </Descriptions.Item>
                <Descriptions.Item label="Email">
                  {userProfile.email}
                </Descriptions.Item>
              </Descriptions>

              <Space size="middle">
                <Button
                  type="primary"
                  icon={<EditOutlined />}
                  onClick={() => navigate("/user/profile/edit")}
                  size="large"
                >
                  Edit Profile
                </Button>
                <Button
                  icon={<ReloadOutlined />}
                  onClick={handleRefresh}
                  disabled={isUserFetching}
                >
                  Refresh Profile
                </Button>
              </Space>
            </>
          ) : (
            <Alert
              message="No Profile"
              description="Unable to load user profile"
              type="warning"
              showIcon
            />
          )}
        </Card>

        {userProfile && (
          <Card>
            <Title level={4}>Account Actions</Title>
            <Button
              danger
              type="primary"
              icon={<LogoutOutlined />}
              onClick={handleSignOut}
              size="large"
            >
              Sign Out
            </Button>
          </Card>
        )}
      </Space>
    </div>
  );
};

export default UserProfile;
