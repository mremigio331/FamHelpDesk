import React, { useEffect, useRef } from "react";
import { Modal, Form, Input, message, Space, Button } from "antd";
import { PlusOutlined } from "@ant-design/icons";
import useCreateQueue from "../../hooks/queue/useCreateQueue";

const { TextArea } = Input;

/**
 * Modal component for creating a new queue
 * @param {boolean} visible - Whether the modal is visible
 * @param {Function} onClose - Callback when modal is closed
 * @param {string} familyId - The family ID where the queue will be created
 * @param {string} groupId - The group ID where the queue will be created
 * @param {Function} onSuccess - Optional callback when queue is created successfully
 */
const CreateQueueModal = ({
  visible,
  onClose,
  familyId,
  groupId,
  onSuccess,
}) => {
  const [form] = Form.useForm();
  const {
    createQueueAsync,
    isCreating,
    isCreateError,
    createError,
    isCreateSuccess,
    createdQueue,
    resetCreateState,
  } = useCreateQueue();

  // Track if we've already handled this success to prevent infinite loops
  const handledSuccessRef = useRef(false);

  // Reset form when modal opens
  useEffect(() => {
    if (visible) {
      form.resetFields();
      handledSuccessRef.current = false; // Reset when modal opens
    }
  }, [visible, form]);

  // Handle successful creation
  useEffect(() => {
    if (isCreateSuccess && createdQueue && !handledSuccessRef.current) {
      handledSuccessRef.current = true;
      message.success("Queue created successfully");
      if (onSuccess) {
        onSuccess(createdQueue);
      }
      onClose();
    }
  }, [isCreateSuccess, createdQueue, onSuccess, onClose]);

  // Handle errors
  useEffect(() => {
    if (isCreateError && createError) {
      const errorMessage =
        createError?.response?.data?.error?.message || "Failed to create queue";
      message.error(errorMessage);
    }
  }, [isCreateError, createError]);

  // Reset state when modal closes
  const handleCancel = () => {
    form.resetFields();
    resetCreateState();
    handledSuccessRef.current = false; // Reset the ref when modal closes
    onClose();
  };

  const handleSubmit = async (values) => {
    if (!familyId || !groupId) {
      message.error("Family ID and Group ID are required");
      return;
    }

    try {
      await createQueueAsync({
        family_id: familyId,
        group_id: groupId,
        queue_name: values.queue_name,
        queue_description: values.queue_description || "",
      });
    } catch (error) {
      // Error handling is done in useEffect
      console.error("Error creating queue:", error);
    }
  };

  return (
    <Modal
      title={
        <Space>
          <PlusOutlined />
          <span>Create New Queue</span>
        </Space>
      }
      open={visible}
      onCancel={handleCancel}
      footer={null}
      width={600}
    >
      <Form form={form} layout="vertical" onFinish={handleSubmit}>
        <Form.Item
          name="queue_name"
          label="Queue Name"
          rules={[
            { required: true, message: "Please enter a queue name" },
            {
              min: 2,
              max: 50,
              message: "Queue name must be between 2 and 50 characters",
            },
            {
              pattern: /^[a-zA-Z0-9\s\-_]+$/,
              message:
                "Queue name can only contain letters, numbers, spaces, hyphens, and underscores",
            },
          ]}
          extra="Choose a descriptive name for your queue"
        >
          <Input
            placeholder="e.g., Bug Reports, Feature Requests, Support Tickets"
            maxLength={50}
            showCount
          />
        </Form.Item>

        <Form.Item
          name="queue_description"
          label="Description (Optional)"
          rules={[
            {
              max: 200,
              message: "Description must be less than 200 characters",
            },
          ]}
          extra="Provide additional context about this queue's purpose"
        >
          <TextArea
            rows={4}
            placeholder="Describe the purpose of this queue and what types of tickets it will contain..."
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
              Create Queue
            </Button>
          </Space>
        </Form.Item>
      </Form>
    </Modal>
  );
};

export default CreateQueueModal;
