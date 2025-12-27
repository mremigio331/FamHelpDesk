import React, { useState } from "react";
import { Card, Form, Input, Button, message } from "antd";
import { TeamOutlined } from "@ant-design/icons";
import { useNavigate } from "react-router-dom";
import useCreateFamily from "../../hooks/family/useCreateFamily";

const { TextArea } = Input;

const CreateFamilyPage = () => {
  const navigate = useNavigate();
  const [form] = Form.useForm();
  const { createFamilyAsync, isCreating } = useCreateFamily();

  const handleSubmit = async (values) => {
    try {
      const response = await createFamilyAsync({
        family_name: values.familyName,
        family_description: values.familyDescription || null,
      });

      message.success("Family created successfully!");

      // Navigate to the new family page
      const familyId = response?.data?.family?.family_id;
      if (familyId) {
        navigate(`/family/${familyId}`);
      } else {
        navigate("/");
      }
    } catch (error) {
      message.error(
        error.response?.data?.message ||
          "Failed to create family. Please try again.",
      );
    }
  };

  const handleCancel = () => {
    navigate(-1);
  };

  return (
    <div
      style={{
        padding: "24px",
        maxWidth: "600px",
        margin: "0 auto",
      }}
    >
      <Card
        title={
          <div style={{ display: "flex", alignItems: "center", gap: "8px" }}>
            <TeamOutlined />
            <span>Create a New Family</span>
          </div>
        }
      >
        <Form
          form={form}
          layout="vertical"
          onFinish={handleSubmit}
          autoComplete="off"
        >
          <Form.Item
            label="Family Name"
            name="familyName"
            rules={[
              {
                required: true,
                message: "Please enter a family name",
              },
              {
                min: 2,
                message: "Family name must be at least 2 characters",
              },
              {
                max: 100,
                message: "Family name must not exceed 100 characters",
              },
            ]}
          >
            <Input
              placeholder="Enter family name"
              size="large"
              disabled={isCreating}
            />
          </Form.Item>

          <Form.Item
            label="Description (Optional)"
            name="familyDescription"
            rules={[
              {
                max: 500,
                message: "Description must not exceed 500 characters",
              },
            ]}
          >
            <TextArea
              placeholder="Enter a description for your family"
              rows={4}
              disabled={isCreating}
            />
          </Form.Item>

          <Form.Item>
            <div
              style={{
                display: "flex",
                gap: "8px",
                justifyContent: "flex-end",
              }}
            >
              <Button onClick={handleCancel} disabled={isCreating}>
                Cancel
              </Button>
              <Button
                type="primary"
                htmlType="submit"
                loading={isCreating}
                icon={<TeamOutlined />}
              >
                Create Family
              </Button>
            </div>
          </Form.Item>
        </Form>
      </Card>
    </div>
  );
};

export default CreateFamilyPage;
