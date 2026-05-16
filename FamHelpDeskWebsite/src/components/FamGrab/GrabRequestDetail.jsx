import React, { useState, useContext, useMemo } from "react";
import {
  Card,
  Typography,
  Tag,
  Button,
  Space,
  List,
  Steps,
  Spin,
  Alert,
  message,
  Divider,
} from "antd";
import {
  ArrowLeftOutlined,
  CheckOutlined,
  CloseOutlined,
  CarryOutOutlined,
  UserOutlined,
  DollarOutlined,
} from "@ant-design/icons";
import { UserAuthenticationContext } from "../../provider/UserAuthenticationProvider";
import { jwtDecode } from "jwt-decode";
import {
  useRequest,
  useClaimRequest,
  useCompleteRequest,
  useCancelRequest,
  useClaimItems,
  useCancelItems,
} from "../../hooks/useFamGrab";
import useGetFamilyMembers from "../../hooks/membership/useGetFamilyMembers";
import ConfirmDeliveryModal from "./ConfirmDeliveryModal";
import CompleteItemModal from "./CompleteItemModal";
import DeliveryPhoto from "./DeliveryPhoto";

const { Title, Text } = Typography;

const statusColors = {
  OPEN: "blue",
  CLAIMED: "orange",
  COMPLETED: "purple",
  CONFIRMED: "green",
  CANCELLED: "red",
  PARTIALLY_CLAIMED: "cyan",
  PARTIALLY_COMPLETED: "geekblue",
};

const getStatusStep = (status) => {
  switch (status) {
    case "OPEN":
      return 0;
    case "PARTIALLY_CLAIMED":
      return 0;
    case "CLAIMED":
      return 1;
    case "PARTIALLY_COMPLETED":
      return 1;
    case "COMPLETED":
      return 2;
    case "CONFIRMED":
      return 3;
    case "CANCELLED":
      return -1;
    default:
      return 0;
  }
};

const GrabRequestDetail = ({ familyId, requestId, onBack }) => {
  const { request, isRequestFetching, isRequestError, refetchRequest } =
    useRequest(familyId, requestId);
  const { claimRequest, isClaiming } = useClaimRequest(familyId);
  const { completeRequest, isCompleting } = useCompleteRequest(familyId);
  const { cancelRequest, isCancelling } = useCancelRequest(familyId);
  const { claimItems, isClaimingItems } = useClaimItems(familyId);
  const { cancelItems, isCancellingItems } = useCancelItems(familyId);
  const { members } = useGetFamilyMembers(familyId);
  const { idToken } = useContext(UserAuthenticationContext);
  const [isConfirmModalVisible, setIsConfirmModalVisible] = useState(false);
  const [confirmingItems, setConfirmingItems] = useState([]);
  const [isCompleteModalVisible, setIsCompleteModalVisible] = useState(false);
  const [completingItem, setCompletingItem] = useState(null);

  // Get current user ID from token
  let currentUserId = null;
  try {
    if (idToken) {
      const decoded = jwtDecode(idToken);
      currentUserId = decoded.sub;
    }
  } catch {
    // ignore decode errors
  }

  // Build a lookup map from user_id to display name
  const memberNameMap = useMemo(() => {
    const map = {};
    if (members && members.length > 0) {
      members.forEach((m) => {
        map[m.user_id] = m.user_display_name || m.user_email || m.user_id;
      });
    }
    return map;
  }, [members]);

  // Resolve an EntityRef (object with id/name) or plain string to a display name
  const getDisplayName = (ref) => {
    if (!ref) return "Unknown";
    if (typeof ref === "object" && ref.name) return ref.name;
    if (typeof ref === "object" && ref.id) return memberNameMap[ref.id] || ref.id;
    return memberNameMap[ref] || ref;
  };

  // Extract the raw user ID from an EntityRef or plain string
  const getUserId = (ref) => {
    if (!ref) return null;
    if (typeof ref === "object") return ref.id;
    return ref;
  };

  if (isRequestFetching && !request) {
    return (
      <div style={{ textAlign: "center", padding: "40px" }}>
        <Spin size="large" />
      </div>
    );
  }

  if (isRequestError) {
    return (
      <Alert
        message="Failed to load request"
        type="error"
        showIcon
        action={
          <Button onClick={onBack} type="link">
            Go Back
          </Button>
        }
      />
    );
  }

  if (!request) return null;

  const requestData = request.request || request;
  const items = request.items || requestData.items || [];

  const isRequestor = currentUserId === getUserId(requestData.requestor_id);
  const isClaimer = currentUserId === getUserId(requestData.claimer_id);
  const currentStep = getStatusStep(requestData.status);

  const handleClaimItem = (itemId) => {
    claimItems(
      { requestId, body: { item_ids: [itemId] } },
      {
        onSuccess: () => {
          message.success("Item claimed!");
          refetchRequest();
        },
        onError: (error) => {
          message.error(
            error?.response?.data?.error?.message || "Failed to claim item",
          );
        },
      },
    );
  };

  const handleCompleteItem = (item) => {
    setCompletingItem(item);
    setIsCompleteModalVisible(true);
  };

  const handleConfirmItem = (item) => {
    setConfirmingItems([item]);
    setIsConfirmModalVisible(true);
  };

  const handleComplete = () => {
    completeRequest(
      { requestId, body: {} },
      {
        onSuccess: () => {
          message.success("Request marked as completed!");
          refetchRequest();
        },
        onError: (error) => {
          message.error(
            error?.response?.data?.error?.message ||
              "Failed to complete request",
          );
        },
      },
    );
  };

  const handleCancel = () => {
    cancelRequest(requestId, {
      onSuccess: () => {
        message.success("Request cancelled");
        refetchRequest();
      },
      onError: (error) => {
        message.error(
          error?.response?.data?.error?.message || "Failed to cancel request",
        );
      },
    });
  };

  const renderActions = () => {
    const actions = [];

    if (requestData.status === "CLAIMED" && isClaimer) {
      actions.push(
        <Button
          key="complete"
          type="primary"
          icon={<CheckOutlined />}
          onClick={handleComplete}
          loading={isCompleting}
        >
          Mark Complete
        </Button>,
      );
    }

    if (requestData.status === "COMPLETED" && isRequestor) {
      actions.push(
        <Button
          key="confirm"
          type="primary"
          icon={<CheckOutlined />}
          onClick={() => {
            const completedItems = items.filter(
              (item) => item.status === "COMPLETED",
            );
            setConfirmingItems(completedItems);
            setIsConfirmModalVisible(true);
          }}
        >
          Confirm Delivery
        </Button>,
      );
    }

    if (
      ["OPEN", "CLAIMED", "COMPLETED", "PARTIALLY_CLAIMED", "PARTIALLY_COMPLETED"].includes(requestData.status) &&
      (isRequestor || isClaimer)
    ) {
      actions.push(
        <Button
          key="cancel"
          danger
          icon={<CloseOutlined />}
          onClick={handleCancel}
          loading={isCancelling}
        >
          Cancel
        </Button>,
      );
    }

    return actions.length > 0 ? <Space wrap>{actions}</Space> : null;
  };

  const renderItemActions = (item) => {
    const actions = [];

    // Per-item "Claim" button for OPEN items (hidden from requestor)
    if (item.status === "OPEN" && !isRequestor) {
      actions.push(
        <Button
          key="claim"
          type="primary"
          size="small"
          icon={<CarryOutOutlined />}
          onClick={() => handleClaimItem(item.item_id)}
          loading={isClaimingItems}
        >
          Claim
        </Button>,
      );
    }

    // Per-item "Mark Complete" button for items claimed by current user with status CLAIMED
    if (item.status === "CLAIMED" && getUserId(item.claimer_id) === currentUserId) {
      actions.push(
        <Button
          key="complete"
          type="primary"
          size="small"
          icon={<CheckOutlined />}
          onClick={() => handleCompleteItem(item)}
        >
          Mark Complete
        </Button>,
      );
    }

    // Per-item "Confirm" button for items with status COMPLETED (visible only to requestor)
    if (item.status === "COMPLETED" && isRequestor) {
      actions.push(
        <Button
          key="confirm"
          size="small"
          icon={<CheckOutlined />}
          onClick={() => handleConfirmItem(item)}
        >
          Confirm
        </Button>,
      );
    }

    return actions.length > 0 ? actions : undefined;
  };

  return (
    <div>
      <Button
        type="link"
        icon={<ArrowLeftOutlined />}
        onClick={onBack}
        style={{ paddingLeft: 0, marginBottom: "16px" }}
      >
        Back to Requests
      </Button>

      <Card>
        <Space direction="vertical" size="large" style={{ width: "100%" }}>
          {/* Header */}
          <div
            style={{
              display: "flex",
              justifyContent: "space-between",
              alignItems: "flex-start",
            }}
          >
            <div>
              <Title level={3} style={{ margin: 0 }}>
                {requestData.title}
              </Title>
              <Space style={{ marginTop: "8px" }}>
                <Tag color={statusColors[requestData.status]}>
                  {requestData.status}
                </Tag>
                <Text type="secondary">
                  {requestData.embolec_cost} Embolecs total
                </Text>
              </Space>
            </div>
          </div>

          {/* People */}
          <Space direction="vertical" size="small">
            <Text>
              <UserOutlined /> Requested by:{" "}
              <Text strong>{getDisplayName(requestData.requestor_id)}</Text>
            </Text>
            {requestData.claimer_id && (
              <Text>
                <CarryOutOutlined /> Claimed by:{" "}
                <Text strong>{getDisplayName(requestData.claimer_id)}</Text>
              </Text>
            )}
          </Space>

          {/* Note */}
          {requestData.note && (
            <div>
              <Text strong>Note:</Text>
              <br />
              <Text>{requestData.note}</Text>
            </div>
          )}

          {/* Status Timeline */}
          {requestData.status !== "CANCELLED" ? (
            <Steps
              current={currentStep}
              size="small"
              items={[
                {
                  title: "Open",
                  description: requestData.created_at
                    ? new Date(requestData.created_at * 1000).toLocaleString()
                    : "",
                },
                {
                  title: "Claimed",
                  description: requestData.claimed_at
                    ? new Date(requestData.claimed_at * 1000).toLocaleString()
                    : "",
                },
                {
                  title: "Completed",
                  description: requestData.completed_at
                    ? new Date(
                        requestData.completed_at * 1000,
                      ).toLocaleString()
                    : "",
                },
                {
                  title: "Confirmed",
                  description: requestData.confirmed_at
                    ? new Date(
                        requestData.confirmed_at * 1000,
                      ).toLocaleString()
                    : "",
                },
              ]}
            />
          ) : (
            <Alert
              message="Request Cancelled"
              description={`Cancelled by ${getDisplayName(requestData.cancelled_by) || "unknown"} on ${requestData.cancelled_at ? new Date(requestData.cancelled_at * 1000).toLocaleString() : "unknown date"}`}
              type="warning"
              showIcon
            />
          )}

          <Divider />

          {/* Items */}
          <div>
            <Title level={5}>Items</Title>
            <List
              dataSource={items}
              renderItem={(item) => (
                <List.Item actions={renderItemActions(item)}>
                  <List.Item.Meta
                    title={
                      <Space>
                        <span>
                          {item.name} (x{item.quantity || 1})
                        </span>
                        <Tag icon={<DollarOutlined />} color="gold">
                          {item.embolec_cost} Embolecs
                        </Tag>
                        <Tag color={statusColors[item.status] || "default"}>
                          {item.status || "OPEN"}
                        </Tag>
                      </Space>
                    }
                    description={
                      <Space direction="vertical" size={0}>
                        {item.note && <Text type="secondary">{item.note}</Text>}
                        {item.claimer_id && (
                          <Text type="secondary">
                            <CarryOutOutlined /> Claimed by:{" "}
                            <Text strong type="secondary">
                              {getDisplayName(item.claimer_id)}
                            </Text>
                          </Text>
                        )}
                      </Space>
                    }
                  />
                </List.Item>
              )}
              locale={{ emptyText: "No items" }}
            />
          </div>

          {/* Delivery Photo */}
          {(requestData.status === "CLAIMED" && isClaimer) ||
          ((requestData.status === "COMPLETED" ||
            requestData.status === "CONFIRMED") &&
            requestData.proof_photo_key) ? (
            <div>
              <Divider />
              <DeliveryPhoto
                familyId={familyId}
                requestId={requestId}
                request={requestData}
                isClaimer={isClaimer}
              />
            </div>
          ) : null}

          {/* Tip info */}
          {requestData.tip_amount && (
            <Text type="success">Tip: {requestData.tip_amount} Embolecs</Text>
          )}

          <Divider />

          {/* Actions */}
          {renderActions()}
        </Space>
      </Card>

      <ConfirmDeliveryModal
        visible={isConfirmModalVisible}
        onClose={() => {
          setIsConfirmModalVisible(false);
          setConfirmingItems([]);
        }}
        familyId={familyId}
        requestId={requestId}
        items={confirmingItems}
        itemIds={confirmingItems.map((item) => item.item_id)}
        embolecCost={confirmingItems.reduce(
          (sum, item) => sum + (item.embolec_cost || 0),
          0,
        )}
        onSuccess={() => {
          setIsConfirmModalVisible(false);
          setConfirmingItems([]);
          refetchRequest();
        }}
      />

      <CompleteItemModal
        visible={isCompleteModalVisible}
        onClose={() => {
          setIsCompleteModalVisible(false);
          setCompletingItem(null);
        }}
        familyId={familyId}
        requestId={requestId}
        itemId={completingItem?.item_id}
        itemName={completingItem?.name}
        onSuccess={() => {
          setIsCompleteModalVisible(false);
          setCompletingItem(null);
          refetchRequest();
        }}
      />
    </div>
  );
};

export default GrabRequestDetail;
