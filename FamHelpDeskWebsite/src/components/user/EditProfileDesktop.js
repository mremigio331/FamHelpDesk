import React, { useState } from "react";
import { Card, Form, Input, Button, Space, Typography, Alert } from "antd";
import {
  EditOutlined,
  ArrowLeftOutlined,
  SaveOutlined,
} from "@ant-design/icons";

const { Title } = Typography;

const EditProfileDesktop = ({
  navigate,
  form,
  userProfile,
  isUserFetching,
  updateProfileAsync,
  isUpdating,
  isUpdateError,
  updateError,
  isUpdateSuccess,
}) => {
  const [successMessage, setSuccessMessage] = useState("");

  const handleSubmit = async (values) => {
    try {
      setSuccessMessage("");
      await updateProfileAsync({
        display_name: values.display_name,
        nick_name: values.nick_name,
      });
      setSuccessMessage("Profile updated successfully!");
      setTimeout(() => {
        navigate("/user/profile");
      }, 1500);
    } catch (error) {
      console.error("Failed to update profile:", error);
    }
  };

  return (
    <div style={{ padding: "50px", maxWidth: "800px", margin: "0 auto" }}>
      <Space direction="vertical" size="large" style={{ width: "100%" }}>
        <div>
          <Button
            type="link"
            icon={<ArrowLeftOutlined />}
            onClick={() => navigate("/user/profile")}
            style={{ paddingLeft: 0 }}
          >
            Back to Profile
          </Button>
        </div>

        <Card loading={isUserFetching}>
          <div
            style={{
              display: "flex",
              alignItems: "center",
              gap: "12px",
              marginBottom: "24px",
            }}
          >
            <EditOutlined style={{ fontSize: "24px" }} />
            <Title level={2} style={{ margin: 0 }}>
              Edit Profile
            </Title>
          </div>

          {isUpdateSuccess && successMessage && (
            <Alert
              message="Success"
              description={successMessage}
              type="success"
              showIcon
              style={{ marginBottom: "20px" }}
            />
          )}

          {isUpdateError && (
            <Alert
              message="Error"
              description={updateError?.message || "Failed to update profile"}
              type="error"
              showIcon
              style={{ marginBottom: "20px" }}
            />
          )}

          <Form
            form={form}
            layout="vertical"
            onFinish={handleSubmit}
            initialValues={{
              display_name: userProfile?.display_name || "",
              nick_name: userProfile?.nick_name || "",
            }}
            disabled={isUpdating}
          >
            <Form.Item
              label="Display Name"
              name="display_name"
              rules={[
                {
                  required: true,
                  message: "Please enter a display name",
                },
                {
                  min: 1,
                  message: "Display name must be at least 1 character",
                },
                {
                  max: 100,
                  message: "Display name must be less than 100 characters",
                },
              ]}
            >
              <Input
                placeholder="Enter your display name"
                size="large"
                maxLength={100}
              />
            </Form.Item>

            <Form.Item
              label="Nickname"
              name="nick_name"
              rules={[
                {
                  required: true,
                  message: "Please enter a nickname",
                },
                {
                  min: 1,
                  message: "Nickname must be at least 1 character",
                },
                {
                  max: 50,
                  message: "Nickname must be less than 50 characters",
                },
              ]}
            >
              <Input
                placeholder="Enter your nickname"
                size="large"
                maxLength={50}
              />
            </Form.Item>

            <Form.Item>
              <Space>
                <Button
                  type="primary"
                  htmlType="submit"
                  icon={<SaveOutlined />}
                  loading={isUpdating}
                  size="large"
                >
                  Save Changes
                </Button>
                <Button
                  onClick={() => navigate("/user/profile")}
                  disabled={isUpdating}
                  size="large"
                >
                  Cancel
                </Button>
              </Space>
            </Form.Item>
          </Form>
        </Card>
      </Space>
    </div>
  );
};

export default EditProfileDesktop;
