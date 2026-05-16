import React, { useState } from "react";
import { Card, Form, Input, Button, Space, Typography, Alert, Select, Switch } from "antd";
import {
  EditOutlined,
  ArrowLeftOutlined,
  SaveOutlined,
} from "@ant-design/icons";

const { Title } = Typography;
const { Option } = Select;

const profileColorOptions = [
  { value: "Black", label: "Black" },
  { value: "White", label: "White" },
  { value: "Red", label: "Red" },
  { value: "Blue", label: "Blue" },
  { value: "Green", label: "Green" },
  { value: "Yellow", label: "Yellow" },
  { value: "Orange", label: "Orange" },
  { value: "Purple", label: "Purple" },
  { value: "Pink", label: "Pink" },
  { value: "Brown", label: "Brown" },
  { value: "Gray", label: "Gray" },
  { value: "Cyan", label: "Cyan" },
];

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
    console.log("Form submitted with values:", values);
    try {
      setSuccessMessage("");
      await updateProfileAsync({
        display_name: values.display_name,
        profile_color: values.profile_color,
        dark_mode: values.dark_mode,
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
              profile_color: userProfile?.profile_color || "Black",
              dark_mode: userProfile?.dark_mode || false,
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
              label="Profile Color"
              name="profile_color"
              rules={[
                {
                  required: true,
                  message: "Please select a profile color",
                },
              ]}
            >
              <Select
                placeholder="Select your profile color"
                size="large"
              >
                {profileColorOptions.map((color) => (
                  <Option key={color.value} value={color.value}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                      <div
                        style={{
                          width: '16px',
                          height: '16px',
                          backgroundColor: color.value.toLowerCase(),
                          border: color.value === 'White' ? '1px solid #d9d9d9' : 'none',
                          borderRadius: '2px',
                        }}
                      />
                      {color.label}
                    </div>
                  </Option>
                ))}
              </Select>
            </Form.Item>

            <Form.Item
              label="Dark Mode"
              name="dark_mode"
              valuePropName="checked"
            >
              <Switch />
            </Form.Item>

            <Form.Item style={{ marginTop: "32px" }}>
              <Space size="large">
                <Button
                  type="primary"
                  htmlType="submit"
                  icon={<SaveOutlined />}
                  loading={isUpdating}
                  size="large"
                  style={{ 
                    minWidth: "140px",
                    fontWeight: "600"
                  }}
                >
                  Save Changes
                </Button>
                <Button
                  onClick={() => navigate("/user/profile")}
                  disabled={isUpdating}
                  size="large"
                  style={{ minWidth: "100px" }}
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
