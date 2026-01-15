import React, { useEffect, useRef } from "react";
import { Modal, Form, Input, message, Space, Button } from "antd";
import { EditOutlined } from "@ant-design/icons";
import useUpdateQueue from "../../hooks/queue/useUpdateQueue";

const { TextArea } = Input;

/**
 * Modal component for editing an existing queue
 * @param {boolean} visible - Whether the modal is visible
 * @param {Function} onClose - Callback when modal is closed
 * @param {Object} queue - The queue object to edit
 * @param {Function} onSuccess - Optional callback when queue is updated successfully
 */
const EditQueueModal = ({ visible, onClose, queue, onSuccess }) => {
  const [form] = Form.useForm();
  const {
    updateQueueAsync,
    isUpdating,
    isUpdateError,
    updateError,
    isUpdateSuccess,
    updatedQueue,
    resetUpdateState,
  } = useUpdateQueue();

  // Track if we've already handled this success to prevent infinite loops
  const handledSuccessRef = useRef(false);

  // Initialize form with queue data when modal opens
  useEffect(() => {
    if (visible && queue) {
      form.setFieldsValue({
        queue_name: queue.queue_name,
        queue_description: queue.queue_description || "",
      });
      handledSuccessRef.current = false; // Reset when modal opens
    }
  }, [visible, queue, form]);

  // Handle successful update
  useEffect(() => {
    if (isUpdateSuccess && updatedQueue && !handledSuccessRef.current) {
      handledSuccessRef.current = true;
      message.success("Queue updated successfully");
      if (onSuccess) {
        onSuccess(updatedQueue);
      }
      onClose();
    }
  }, [isUpdateSuccess, updatedQueue, onSuccess, onClose]);

  // Handle errors
  useEffect(() => {
    if (isUpdateError && updateError) {
      const errorMessage =
        updateError?.response?.data?.error?.message || "Failed to update queue";
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
    if (!queue) {
      message.error("No queue selected for editing");
      return;
    }

    try {
      await updateQueueAsync({
        family_id: queue.family_id,
        queue_id: queue.queue_id,
        queue_name: values.queue_name,
        queue_description: values.queue_description || "",
      });
    } catch (error) {
      // Error handling is done in useEffect
      console.error("Error updating queue:", error);
    }
  };

  if (!queue) {
    return null;
  }

  return (
    <Modal
      title={
        <Space>
          <EditOutlined />
          <span>Edit Queue</span>
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

export default EditQueueModal;
