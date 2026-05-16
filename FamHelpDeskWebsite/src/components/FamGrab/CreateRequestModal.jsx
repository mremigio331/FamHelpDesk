import React from "react";
import {
  Modal,
  Form,
  Input,
  InputNumber,
  Button,
  Space,
  Typography,
  message,
} from "antd";
import { PlusOutlined, MinusCircleOutlined } from "@ant-design/icons";
import { useCreateRequest } from "../../hooks/useFamGrab";

const { Text } = Typography;

const CreateRequestModal = ({ visible, onClose, familyId }) => {
  const [form] = Form.useForm();
  const { createRequest, isCreating } = useCreateRequest(familyId);

  const handleSubmit = async () => {
    try {
      const values = await form.validateFields();
      const body = {
        title: values.title,
        items: values.items.map((item) => ({
          name: item.name,
          embolec_cost: item.embolec_cost || 0,
          quantity: item.quantity || 1,
          note: item.note || null,
        })),
        note: values.note || null,
      };

      createRequest(body, {
        onSuccess: () => {
          message.success("Request created successfully");
          form.resetFields();
          onClose();
        },
        onError: (error) => {
          message.error(
            error?.response?.data?.message || "Failed to create request",
          );
        },
      });
    } catch {
      // Form validation failed
    }
  };

  return (
    <Modal
      title="Create New Request"
      open={visible}
      onCancel={onClose}
      onOk={handleSubmit}
      confirmLoading={isCreating}
      okText="Create Request"
      width={650}
      destroyOnClose
    >
      <Form
        form={form}
        layout="vertical"
        initialValues={{ items: [{ name: "", embolec_cost: 1, quantity: 1 }] }}
      >
        <Form.Item
          name="title"
          label="Title"
          rules={[{ required: true, message: "Please enter a title" }]}
        >
          <Input placeholder="e.g., Party Supplies, Snack Run" />
        </Form.Item>

        <Form.List
          name="items"
          rules={[
            {
              validator: async (_, items) => {
                if (!items || items.length < 1) {
                  return Promise.reject(
                    new Error("At least one item is required"),
                  );
                }
                const totalCost = items.reduce(
                  (sum, item) => sum + (item?.embolec_cost || 0),
                  0,
                );
                if (totalCost < 1) {
                  return Promise.reject(
                    new Error("Total cost must be at least 1 Embolec"),
                  );
                }
              },
            },
          ]}
        >
          {(fields, { add, remove }, { errors }) => (
            <>
              <Text strong style={{ display: "block", marginBottom: 8 }}>
                Items
              </Text>
              {fields.map(({ key, name, ...restField }) => (
                <Space
                  key={key}
                  style={{ display: "flex", marginBottom: 8 }}
                  align="baseline"
                >
                  <Form.Item
                    {...restField}
                    name={[name, "name"]}
                    rules={[
                      { required: true, message: "Name required" },
                    ]}
                  >
                    <Input placeholder="Item name" style={{ width: 180 }} />
                  </Form.Item>
                  <Form.Item
                    {...restField}
                    name={[name, "embolec_cost"]}
                    rules={[
                      { required: true, message: "Cost required" },
                      { type: "number", min: 1, message: "Min 1" },
                    ]}
                  >
                    <InputNumber
                      min={1}
                      placeholder="Cost"
                      style={{ width: 90 }}
                      addonAfter="E"
                    />
                  </Form.Item>
                  <Form.Item {...restField} name={[name, "quantity"]}>
                    <InputNumber min={1} placeholder="Qty" style={{ width: 70 }} />
                  </Form.Item>
                  <Form.Item {...restField} name={[name, "note"]}>
                    <Input placeholder="Note" style={{ width: 120 }} />
                  </Form.Item>
                  {fields.length > 1 && (
                    <MinusCircleOutlined onClick={() => remove(name)} />
                  )}
                </Space>
              ))}
              <Form.Item>
                <Button
                  type="dashed"
                  onClick={() => add({ name: "", embolec_cost: 1, quantity: 1 })}
                  icon={<PlusOutlined />}
                  block
                >
                  Add Item
                </Button>
              </Form.Item>
              <Form.ErrorList errors={errors} />
            </>
          )}
        </Form.List>

        <Form.Item
          noStyle
          shouldUpdate={(prev, cur) => prev.items !== cur.items}
        >
          {({ getFieldValue }) => {
            const items = getFieldValue("items") || [];
            const total = items.reduce(
              (sum, item) => sum + (item?.embolec_cost || 0),
              0,
            );
            return (
              <div
                style={{
                  padding: "8px 12px",
                  background: "#f5f5f5",
                  borderRadius: "6px",
                  marginBottom: 16,
                }}
              >
                <Text strong>Total Cost: {total} Embolecs</Text>
              </div>
            );
          }}
        </Form.Item>

        <Form.Item name="note" label="Note (optional)">
          <Input.TextArea
            rows={2}
            placeholder="Any additional details..."
          />
        </Form.Item>
      </Form>
    </Modal>
  );
};

export default CreateRequestModal;
