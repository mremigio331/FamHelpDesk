import React, { useEffect, useRef } from "react";
import { Modal, Form, Input, message, Space, Button } from "antd";
import { EditOutlined } from "@ant-design/icons";
import useUpdateGroup from "../../hooks/group/useUpdateGroup";

const { TextArea } = Input;

/**
 * Modal component for editing an existing group
 * @param {boolean} visible - Whether the modal is visible
 * @param {Function} onClose - Callback when modal is closed
 * @param {Object} group - The group object to edit
 * @param {Function} onSuccess - Optional callback when group is updated successfully
 */
const EditGroupModal = ({ visible, onClose, group, onSuccess }) => {
  const [form] = Form.useForm();
  const {
    updateGroupAsync,
    isUpdating,
    isUpdateError,
    updateError,
    isUpdateSuccess,
    updatedGroup,
    resetUpdateState,
  } = useUpdateGroup();

  // Track if we've already handled this success to prevent infinite loops
  const handledSuccessRef = useRef(false);

  // Initialize form with group data when modal opens
  useEffect(() => {
    if (visible && group) {
      form.setFieldsValue({
        group_name: group.group_name,
        group_description: group.group_description || "",
      });
      handledSuccessRef.current = false; // Reset when modal opens
    }
  }, [visible, group, form]);

  // Handle successful update
  useEffect(() => {
    if (isUpdateSuccess && updatedGroup && !handledSuccessRef.current) {
      handledSuccessRef.current = true;
      message.success("Group updated successfully");
      if (onSuccess) {
        onSuccess(updatedGroup);
      }
      onClose();
    }
  }, [isUpdateSuccess, updatedGroup, onSuccess, onClose]);

  // Handle errors
  useEffect(() => {
    if (isUpdateError && updateError) {
      const errorMessage =
        updateError?.response?.data?.error?.message || "Failed to update group";
      message.error(errorMessage);
    }
  }, [isUpdateError, updateError]);

  // Reset state when modal closes
  const handleCancel = () => {
    form.resetFields();
    resetUpdateState();
    handledSuccessRef.current = false; // Reset the ref when modal closes
    onClose();
  };

  const handleSubmit = async (values) => {
    if (!group) {
      message.error("No group selected for editing");
      return;
    }

    try {
      await updateGroupAsync({
        family_id: group.family_id,
        group_id: group.group_id,
        group_name: values.group_name,
        group_description: values.group_description || "",
      });
    } catch (error) {
      // Error handling is done in useEffect
      console.error("Error updating group:", error);
    }
  };

  if (!group) {
    return null;
  }

  return (
    <Modal
      title={
        <Space>
          <EditOutlined />
          <span>Edit Group</span>
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
            <Button onClick={handleCancel} disabled={isUpdating}>
              Cancel
            </Button>
            <Button type="primary" htmlType="submit" loading={isUpdating}>
              Save Changes
            </Button>
          </Space>
        </Form.Item>
      </Form>
    </Modal>
  );
};

export default EditGroupModal;
