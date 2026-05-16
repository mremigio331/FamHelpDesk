import React, { useState, useMemo } from "react";
import { Modal, InputNumber, Typography, Space, List, Tag, message } from "antd";
import { DollarOutlined } from "@ant-design/icons";
import { useConfirmItems } from "../../hooks/useFamGrab";

const { Text } = Typography;

const ConfirmDeliveryModal = ({
  visible,
  onClose,
  familyId,
  requestId,
  items = [],
  itemIds = [],
  embolecCost,
  onSuccess,
}) => {
  const [tipAmount, setTipAmount] = useState(null);
  const { confirmItems, isConfirmingItems } = useConfirmItems(familyId);

  const totalItemCost = useMemo(() => {
    if (items.length > 0) {
      return items.reduce((sum, item) => sum + (item.embolec_cost || 0), 0);
    }
    return embolecCost || 0;
  }, [items, embolecCost]);

  const totalCost = totalItemCost + (tipAmount || 0);

  // Count distinct claimers from the items being confirmed
  const distinctClaimers = useMemo(() => {
    const claimerSet = new Set();
    items.forEach((item) => {
      if (item.claimer_id) {
        const id = typeof item.claimer_id === "object" ? item.claimer_id.id : item.claimer_id;
        claimerSet.add(id);
      }
    });
    return claimerSet.size;
  }, [items]);

  const handleConfirm = () => {
    const body = {
      item_ids: itemIds,
    };
    if (tipAmount && tipAmount >= 1) {
      body.tip_amount = tipAmount;
    }

    confirmItems(
      { requestId, body },
      {
        onSuccess: () => {
          message.success("Delivery confirmed! Embolecs transferred.");
          setTipAmount(null);
          onSuccess();
        },
        onError: (error) => {
          message.error(
            error?.response?.data?.error?.message ||
              error?.response?.data?.message ||
              "Failed to confirm delivery",
          );
        },
      },
    );
  };

  return (
    <Modal
      title="Confirm Delivery"
      open={visible}
      onCancel={onClose}
      onOk={handleConfirm}
      confirmLoading={isConfirmingItems}
      okText="Confirm & Pay"
      destroyOnClose
    >
      <Space direction="vertical" size="middle" style={{ width: "100%" }}>
        {items.length > 0 && (
          <div>
            <Text strong>Items being confirmed:</Text>
            <List
              size="small"
              dataSource={items}
              renderItem={(item) => (
                <List.Item>
                  <Space>
                    <span>{item.name} (x{item.quantity || 1})</span>
                    <Tag icon={<DollarOutlined />} color="gold">
                      {item.embolec_cost} Embolecs
                    </Tag>
                  </Space>
                </List.Item>
              )}
              style={{ marginTop: "8px" }}
            />
          </div>
        )}

        <Text>
          Confirming will transfer{" "}
          <Text strong>{totalItemCost} Embolecs</Text> to the claimer(s).
        </Text>

        <div>
          <Text>Add a tip (optional):</Text>
          <InputNumber
            min={1}
            value={tipAmount}
            onChange={setTipAmount}
            placeholder="Tip amount"
            style={{ width: "100%", marginTop: "8px" }}
            addonAfter="Embolecs"
          />
          {distinctClaimers > 1 && tipAmount > 0 && (
            <Text type="secondary" style={{ display: "block", marginTop: "4px" }}>
              Tip will be split equally among {distinctClaimers} claimer(s)
            </Text>
          )}
        </div>

        <div
          style={{
            padding: "12px",
            background: "#f5f5f5",
            borderRadius: "6px",
          }}
        >
          <Text strong>Total transfer: {totalCost} Embolecs</Text>
          {tipAmount > 0 && (
            <Text type="secondary" style={{ display: "block" }}>
              ({totalItemCost} cost + {tipAmount} tip)
            </Text>
          )}
        </div>
      </Space>
    </Modal>
  );
};

export default ConfirmDeliveryModal;
