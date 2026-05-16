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

const EditProfileMobile = ({
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
    <div style={{ padding: "16px", maxWidth: "800px", margin: "0 auto" }}>
      <Space direction="vertical" size="middle" style={{ width: "100%" }}>
        <div>
          <Button
            type="link"
            icon={<ArrowLeftOutlined />}
            onClick={() => navigate("/user/profile")}
            style={{ paddingLeft: 0, fontSize: "12px" }}
          >
            Back to Profile
          </Button>
        </div>

        <Card loading={isUserFetching} bodyStyle={{ padding: "16px" }}>
          <div
            style={{
              display: "flex",
              alignItems: "center",
              gap: "8px",
              marginBottom: "16px",
            }}
          >
            <EditOutlined style={{ fontSize: "16px" }} />
            <Title level={4} style={{ margin: 0, fontSize: "18px" }}>
              Edit Profile
            </Title>
          </div>

          {isUpdateSuccess && successMessage && (
            <Alert
              message="Success"
              description={successMessage}
              type="success"
              showIcon
              style={{ marginBottom: "16px", fontSize: "12px" }}
            />
          )}

          {isUpdateError && (
            <Alert
              message="Error"
              description={updateError?.message || "Failed to update profile"}
              type="error"
              showIcon
              style={{ marginBottom: "16px", fontSize: "12px" }}
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
              label={<span style={{ fontSize: "13px" }}>Display Name</span>}
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
                size="middle"
                maxLength={100}
                style={{ fontSize: "13px" }}
              />
            </Form.Item>

            <Form.Item
              label={<span style={{ fontSize: "13px" }}>Profile Color</span>}
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
                size="middle"
                style={{ fontSize: "13px" }}
              >
                {profileColorOptions.map((color) => (
                  <Option key={color.value} value={color.value}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                      <div
                        style={{
                          width: '12px',
                          height: '12px',
                          backgroundColor: color.value.toLowerCase(),
                          border: color.value === 'White' ? '1px solid #d9d9d9' : 'none',
                          borderRadius: '2px',
                        }}
                      />
                      <span style={{ fontSize: "13px" }}>{color.label}</span>
                    </div>
                  </Option>
                ))}
              </Select>
            </Form.Item>

            <Form.Item
              label={<span style={{ fontSize: "13px" }}>Dark Mode</span>}
              name="dark_mode"
              valuePropName="checked"
            >
              <Switch size="small" />
            </Form.Item>

            <Form.Item style={{ marginTop: "24px" }}>
              <Space
                direction="vertical"
                style={{ width: "100%" }}
                size="middle"
              >
                <Button
                  type="primary"
                  htmlType="submit"
                  icon={<SaveOutlined />}
                  loading={isUpdating}
                  size="middle"
                  block
                  style={{ 
                    fontSize: "14px",
                    fontWeight: "600",
                    height: "40px"
                  }}
                >
                  Save Changes
                </Button>
                <Button
                  onClick={() => navigate("/user/profile")}
                  disabled={isUpdating}
                  size="middle"
                  block
                  style={{ 
                    fontSize: "13px",
                    height: "36px"
                  }}
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

export default EditProfileMobile;
