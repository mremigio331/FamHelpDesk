import React from "react";
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

const { Title } = Typography;

const UserProfileMobile = ({
  navigate,
  logoutUser,
  userProfile,
  isUserFetching,
  isUserError,
  userError,
  userRefetch,
}) => {
  const handleSignOut = () => {
    logoutUser();
  };

  const handleRefresh = () => {
    userRefetch();
  };

  return (
    <div style={{ padding: "16px", maxWidth: "800px", margin: "0 auto" }}>
      <Space direction="vertical" size="middle" style={{ width: "100%" }}>
        <div>
          <Button
            type="link"
            icon={<ArrowLeftOutlined />}
            onClick={() => navigate("/")}
            style={{ paddingLeft: 0, fontSize: "12px" }}
          >
            Back to Home
          </Button>
        </div>

        <Card bodyStyle={{ padding: "16px" }}>
          <div
            style={{
              display: "flex",
              alignItems: "center",
              gap: "8px",
              marginBottom: "16px",
            }}
          >
            <UserOutlined style={{ fontSize: "16px" }} />
            <Title level={4} style={{ margin: 0, fontSize: "18px" }}>
              User Profile
            </Title>
          </div>

          {isUserFetching ? (
            <div style={{ textAlign: "center", padding: "24px" }}>
              <Spin size="default" />
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
                size="small"
                style={{ marginBottom: "16px" }}
                labelStyle={{
                  fontSize: "12px",
                  fontWeight: "600",
                  padding: "8px 12px",
                }}
                contentStyle={{
                  fontSize: "12px",
                  padding: "8px 12px",
                }}
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

              <Space
                size="small"
                direction="vertical"
                style={{ width: "100%" }}
              >
                <Button
                  type="primary"
                  icon={<EditOutlined />}
                  onClick={() => navigate("/user/profile/edit")}
                  size="middle"
                  block
                  style={{ fontSize: "13px" }}
                >
                  Edit Profile
                </Button>
                <Button
                  icon={<ReloadOutlined />}
                  onClick={handleRefresh}
                  disabled={isUserFetching}
                  size="middle"
                  block
                  style={{ fontSize: "13px" }}
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
          <Card bodyStyle={{ padding: "16px" }}>
            <Title
              level={5}
              style={{
                margin: "0 0 12px 0",
                fontSize: "14px",
              }}
            >
              Account Actions
            </Title>
            <Button
              danger
              type="primary"
              icon={<LogoutOutlined />}
              onClick={handleSignOut}
              size="middle"
              block
              style={{ fontSize: "13px" }}
            >
              Sign Out
            </Button>
          </Card>
        )}
      </Space>
    </div>
  );
};

export default UserProfileMobile;
