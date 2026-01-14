import React, { useEffect } from "react";
import { Modal, Form, Input, message, Space, Button } from "antd";
import { TeamOutlined } from "@ant-design/icons";
import useCreateGroup from "../../hooks/group/useCreateGroup";

const { TextArea } = Input;

/**
 * Modal component for creating a new group
 * @param {boolean} visible - Whether the modal is visible
 * @param {Function} onClose - Callback when modal is closed
 * @param {string} familyId - The family ID to create the group in
 * @param {Function} onSuccess - Optional callback when group is created successfully
 */
const CreateGroupModal = ({ visible, onClose, familyId, onSuccess }) => {
  const [form] = Form.useForm();
  const {
    createGroup,
    isCreating,
    isCreateError,
    createError,
    isCreateSuccess,
    createdGroup,
    resetCreateState,
  } = useCreateGroup();

  // Handle successful creation
  useEffect(() => {
    if (isCreateSuccess && createdGroup) {
      message.success("Group created successfully");
      form.resetFields();
      if (onSuccess) {
        onSuccess(createdGroup);
      }
      onClose();
    }
  }, [isCreateSuccess, createdGroup, form, onSuccess, onClose]);

  // Handle errors
  useEffect(() => {
    if (isCreateError && createError) {
      const errorMessage =
        createError?.response?.data?.error?.message || "Failed to create group";
      message.error(errorMessage);
    }
  }, [isCreateError, createError]);

  // Reset state when modal closes
  const handleCancel = () => {
    form.resetFields();
    resetCreateState();
    onClose();
  };

  const handleSubmit = async (values) => {
    try {
      await createGroup({
        family_id: familyId,
        group_name: values.group_name,
        group_description: values.group_description || "",
      });
    } catch (error) {
      // Error handling is done in useEffect
      console.error("Error creating group:", error);
    }
  };

  return (
    <Modal
      title={
        <Space>
          <TeamOutlined />
          <span>Create New Group</span>
        </Space>
      }
      open={visible}
      onCancel={handleCancel}
      footer={null}
      width={600}
    >
      <Form form={form} layout="vertical" onFinish={handleSubmit}>
        <Form.Item
          name="group_name"
          label="Group Name"
          rules={[
            { required: true, message: "Please enter a group name" },
            {
              min: 2,
              max: 50,
              message: "Group name must be between 2 and 50 characters",
            },
            {
              pattern: /^[a-zA-Z0-9\s\-_]+$/,
              message:
                "Group name can only contain letters, numbers, spaces, hyphens, and underscores",
            },
          ]}
          extra="Choose a descriptive name for your group"
        >
          <Input
            placeholder="e.g., IT Support, Marketing Team, Bug Reports"
            maxLength={50}
            showCount
          />
        </Form.Item>

        <Form.Item
          name="group_description"
          label="Description (Optional)"
          rules={[
            {
              max: 200,
              message: "Description must be less than 200 characters",
            },
          ]}
          extra="Provide additional context about this group's purpose"
        >
          <TextArea
            rows={4}
            placeholder="Describe the purpose of this group and what it will be used for..."
            maxLength={200}
            showCount
          />
        </Form.Item>

        <Form.Item style={{ marginBottom: 0 }}>
          <Space style={{ width: "100%", justifyContent: "flex-end" }}>
            <Button onClick={handleCancel} disabled={isCreating}>
              Cancel
            </Button>
            <Button type="primary" htmlType="submit" loading={isCreating}>
              Create Group
            </Button>
          </Space>
        </Form.Item>
      </Form>
    </Modal>
  );
};

export default CreateGroupModal;
