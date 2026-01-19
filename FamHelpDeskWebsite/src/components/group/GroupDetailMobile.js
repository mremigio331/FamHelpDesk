import React, { useEffect } from "react";
import { useParams, useNavigate } from "react-router-dom";
import {
  Card,
  Typography,
  Button,
  Space,
  Spin,
  Alert,
  Tabs,
  Descriptions,
  Tag,
  Modal,
  message,
  Popconfirm,
  List,
  Avatar,
  Statistic,
  Row,
  Col,
  Drawer,
  Empty,
} from "antd";
import {
  ArrowLeftOutlined,
  EditOutlined,
  DeleteOutlined,
  TeamOutlined,
  UserOutlined,
  InboxOutlined,
  SettingOutlined,
  UserAddOutlined,
  UserDeleteOutlined,
  CrownOutlined,
  PlusOutlined,
} from "@ant-design/icons";
import useGroupDetail from "./useGroupDetail";
import useGroups from "../../hooks/group/useGroups";
import useGetGroupMembers from "../../hooks/group/membership/useGetGroupMembers";
import useGetGroupMembershipRequests from "../../hooks/group/membership/useGetGroupMembershipRequests";
import useReviewGroupMembership from "../../hooks/group/membership/useReviewGroupMembership";
import useRemoveGroupMember from "../../hooks/group/membership/useRemoveGroupMember";
import useUpdateGroupMemberRole from "../../hooks/group/membership/useUpdateGroupMemberRole";
import useGetQueues from "../../hooks/queue/useGetQueues";
import EditGroupModal from "./EditGroupModal";
import CreateQueueModal from "../queue/CreateQueueModal";
import QueueListItemMobile from "../queue/QueueListItemMobile";

const { Title, Text, Paragraph } = Typography;

const GroupDetailMobile = () => {
  const { familyId, groupId } = useParams();
  const navigate = useNavigate();

  const {
    activeTab,
    handleTabChange,
    isEditModalVisible,
    showEditModal,
    hideEditModal,
    isDeleteModalVisible,
    showDeleteModal,
    hideDeleteModal,
  } = useGroupDetail();

  const [isCreateQueueModalVisible, setIsCreateQueueModalVisible] =
    React.useState(false);

  const {
    allGroups,
    isLoading: isGroupsLoading,
    hasError: hasGroupsError,
    deleteGroup,
    isDeleting,
    isDeleteSuccess,
    refetchGroups,
  } = useGroups(familyId);

  const {
    members,
    memberCount,
    isFetchingMembers,
    isMembersError,
    refetchMembers,
  } = useGetGroupMembers(familyId, groupId);

  const {
    requests,
    requestCount,
    isFetchingRequests,
    isRequestsError,
    refetchRequests,
  } = useGetGroupMembershipRequests(familyId, groupId);

  const { reviewMembership, isReviewingMembership, isReviewSuccess } =
    useReviewGroupMembership();

  const { removeMember, isRemovingMember, isRemoveMemberSuccess } =
    useRemoveGroupMember();

  const { updateMemberRole, isUpdatingRole, isUpdateRoleSuccess } =
    useUpdateGroupMemberRole();

  // Fetch queues for this group
  const { queues, isQueuesFetching, isQueuesError, queuesRefetch } =
    useGetQueues(familyId, groupId, true);

  // Find the current group
  const group = allGroups?.find((g) => g.group_id === groupId);
  const currentUserMembership = members?.find(
    (m) => m.is_current_user === true,
  );
  const isAdmin = currentUserMembership?.is_admin === true;

  // Handle successful operations

  useEffect(() => {
    if (isDeleteSuccess) {
      message.success("Group deleted successfully");
      navigate(`/family/${familyId}`);
    }
  }, [isDeleteSuccess, navigate, familyId]);

  useEffect(() => {
    if (isReviewSuccess) {
      message.success("Membership request reviewed");
      refetchRequests();
      refetchMembers();
    }
  }, [isReviewSuccess, refetchRequests, refetchMembers]);

  useEffect(() => {
    if (isRemoveMemberSuccess) {
      message.success("Member removed successfully");
      refetchMembers();
    }
  }, [isRemoveMemberSuccess, refetchMembers]);

  useEffect(() => {
    if (isUpdateRoleSuccess) {
      message.success("Member role updated successfully");
      refetchMembers();
    }
  }, [isUpdateRoleSuccess, refetchMembers]);

  const handleDelete = async () => {
    try {
      await deleteGroup({
        family_id: familyId,
        group_id: groupId,
      });
    } catch (error) {
      message.error("Failed to delete group");
      hideDeleteModal();
    }
  };

  const handleApproveRequest = async (userId) => {
    try {
      await reviewMembership({
        familyId: familyId,
        groupId: groupId,
        targetUserId: userId,
        approve: true,
      });
    } catch (error) {
      message.error("Failed to approve membership request");
    }
  };

  const handleRejectRequest = async (userId) => {
    try {
      await reviewMembership({
        familyId: familyId,
        groupId: groupId,
        targetUserId: userId,
        approve: false,
      });
    } catch (error) {
      message.error("Failed to reject membership request");
    }
  };

  const handleRemoveMember = async (userId) => {
    try {
      await removeMember({
        familyId: familyId,
        groupId: groupId,
        targetUserId: userId,
      });
    } catch (error) {
      message.error("Failed to remove member");
    }
  };

  const handleToggleAdmin = async (userId, currentIsAdmin) => {
    try {
      await updateMemberRole({
        familyId: familyId,
        groupId: groupId,
        targetUserId: userId,
        isAdmin: !currentIsAdmin,
      });
    } catch (error) {
      message.error("Failed to update member role");
    }
  };

  if (isGroupsLoading) {
    return (
      <div style={{ padding: "50px", textAlign: "center" }}>
        <Spin size="large" />
      </div>
    );
  }

  if (hasGroupsError || !group) {
    return (
      <div style={{ padding: "16px" }}>
        <Alert
          message="Group Not Found"
          description="This group does not exist or you don't have access to it."
          type="warning"
          showIcon
          action={
            <Button
              type="primary"
              size="small"
              onClick={() => navigate(`/family/${familyId}`)}
            >
              Back to Family
            </Button>
          }
        />
      </div>
    );
  }

  const renderOverview = () => (
    <div>
      <Card size="small" style={{ marginBottom: "12px" }}>
        <Title level={5}>Group Information</Title>
        <Descriptions column={1} size="small">
          <Descriptions.Item label="Name">{group.group_name}</Descriptions.Item>
          <Descriptions.Item label="Description">
            {group.group_description || "No description"}
          </Descriptions.Item>
          <Descriptions.Item label="Created">
            {new Date(group.creation_date * 1000).toLocaleDateString()}
          </Descriptions.Item>
          <Descriptions.Item label="Your Role">
            {isAdmin ? (
              <Tag color="blue" icon={<CrownOutlined />}>
                Admin
              </Tag>
            ) : (
              <Tag color="green">Member</Tag>
            )}
          </Descriptions.Item>
        </Descriptions>
      </Card>

      <Card size="small">
        <Title level={5}>Statistics</Title>
        <Row gutter={[8, 8]}>
          <Col span={24}>
            <Card size="small" style={{ backgroundColor: "#f0f5ff" }}>
              <Statistic
                title="Members"
                value={memberCount}
                prefix={<UserOutlined />}
              />
            </Card>
          </Col>
          <Col span={24}>
            <Card size="small" style={{ backgroundColor: "#f6ffed" }}>
              <Statistic
                title="Queues"
                value={queues?.length || 0}
                prefix={<InboxOutlined />}
              />
            </Card>
          </Col>
          <Col span={24}>
            <Card size="small" style={{ backgroundColor: "#fff7e6" }}>
              <Statistic
                title="Pending Requests"
                value={requestCount}
                prefix={<UserAddOutlined />}
              />
            </Card>
          </Col>
        </Row>
      </Card>
    </div>
  );

  const renderMembers = () => (
    <Card
      size="small"
      title={
        <Space>
          <UserOutlined />
          <span>Members ({memberCount})</span>
        </Space>
      }
    >
      {isFetchingMembers ? (
        <div style={{ textAlign: "center", padding: "20px" }}>
          <Spin />
        </div>
      ) : isMembersError ? (
        <Alert
          message="Error"
          description="Failed to load members"
          type="error"
          showIcon
        />
      ) : (
        <List
          size="small"
          dataSource={members}
          renderItem={(member) => (
            <List.Item
              style={{
                padding: "12px 0",
                minHeight: "60px",
              }}
              actions={
                isAdmin && !member.is_current_user
                  ? [
                      <Button
                        key="toggle-admin"
                        type="link"
                        size="small"
                        icon={<CrownOutlined />}
                        onClick={() =>
                          handleToggleAdmin(member.user_id, member.is_admin)
                        }
                        loading={isUpdatingRole}
                        style={{ fontSize: "12px" }}
                      >
                        {member.is_admin ? "Remove Admin" : "Make Admin"}
                      </Button>,
                      <Popconfirm
                        key="remove"
                        title="Remove member?"
                        description="Remove this member from the group?"
                        onConfirm={() => handleRemoveMember(member.user_id)}
                        okText="Yes"
                        cancelText="No"
                      >
                        <Button
                          type="link"
                          size="small"
                          danger
                          icon={<UserDeleteOutlined />}
                          loading={isRemovingMember}
                          style={{ fontSize: "12px" }}
                        >
                          Remove
                        </Button>
                      </Popconfirm>,
                    ]
                  : []
              }
            >
              <List.Item.Meta
                avatar={
                  <Avatar
                    size={40}
                    icon={<UserOutlined />}
                    style={{ backgroundColor: "#1890ff" }}
                  />
                }
                title={
                  <Space size="small" wrap>
                    <span style={{ fontSize: "14px", fontWeight: "500" }}>
                      {member.user_display_name || member.user_email}
                    </span>
                    {member.is_admin && (
                      <Tag color="blue" icon={<CrownOutlined />}>
                        Admin
                      </Tag>
                    )}
                    {member.is_current_user && <Tag color="green">You</Tag>}
                  </Space>
                }
                description={
                  <Text type="secondary" style={{ fontSize: "12px" }}>
                    {member.user_email}
                  </Text>
                }
              />
            </List.Item>
          )}
        />
      )}
    </Card>
  );

  const renderMembershipRequests = () => {
    if (!isAdmin) {
      return (
        <Card size="small">
          <Alert
            message="Admin Only"
            description="Only group admins can view and manage membership requests."
            type="info"
            showIcon
          />
        </Card>
      );
    }

    return (
      <Card
        size="small"
        title={
          <Space>
            <UserAddOutlined />
            <span>Requests ({requestCount})</span>
          </Space>
        }
      >
        {isFetchingRequests ? (
          <div style={{ textAlign: "center", padding: "20px" }}>
            <Spin />
          </div>
        ) : isRequestsError ? (
          <Alert
            message="Error"
            description="Failed to load membership requests"
            type="error"
            showIcon
          />
        ) : requests.length === 0 ? (
          <Alert
            message="No Pending Requests"
            description="There are no pending membership requests."
            type="info"
            showIcon
          />
        ) : (
          <List
            size="small"
            dataSource={requests}
            renderItem={(request) => (
              <List.Item
                style={{
                  padding: "12px 0",
                  minHeight: "60px",
                }}
                actions={[
                  <Button
                    key="approve"
                    type="primary"
                    size="middle"
                    onClick={() => handleApproveRequest(request.user_id)}
                    loading={isReviewingMembership}
                    style={{ minWidth: "80px", height: "40px" }}
                  >
                    Approve
                  </Button>,
                  <Button
                    key="reject"
                    danger
                    size="middle"
                    onClick={() => handleRejectRequest(request.user_id)}
                    loading={isReviewingMembership}
                    style={{ minWidth: "80px", height: "40px" }}
                  >
                    Reject
                  </Button>,
                ]}
              >
                <List.Item.Meta
                  avatar={
                    <Avatar
                      size={40}
                      icon={<UserOutlined />}
                      style={{ backgroundColor: "#52c41a" }}
                    />
                  }
                  title={
                    <span style={{ fontSize: "14px", fontWeight: "500" }}>
                      {request.user_display_name || request.user_email}
                    </span>
                  }
                  description={
                    <Space direction="vertical" size={0}>
                      <Text type="secondary" style={{ fontSize: "12px" }}>
                        {request.user_email}
                      </Text>
                      <Text type="secondary" style={{ fontSize: "11px" }}>
                        {new Date(
                          request.request_date * 1000,
                        ).toLocaleDateString()}
                      </Text>
                    </Space>
                  }
                />
              </List.Item>
            )}
          />
        )}
      </Card>
    );
  };

  const renderQueues = () => (
    <Card size="small">
      <Space
        direction="vertical"
        size="middle"
        style={{ width: "100%", padding: "8px 0" }}
      >
        {/* Create Queue Button */}
        {isAdmin && (
          <Button
            type="primary"
            icon={<PlusOutlined />}
            onClick={() => setIsCreateQueueModalVisible(true)}
            block
            size="large"
            style={{ height: "44px" }}
          >
            Create Queue
          </Button>
        )}

        {/* Queue List */}
        {isQueuesFetching ? (
          <div style={{ textAlign: "center", padding: "40px 20px" }}>
            <Spin size="large" />
          </div>
        ) : isQueuesError ? (
          <Alert
            message="Error"
            description="Failed to load queues"
            type="error"
            showIcon
          />
        ) : queues && queues.length > 0 ? (
          <div>
            {queues.map((queue) => (
              <QueueListItemMobile
                key={queue.queue_id}
                queue={queue}
                onClick={() =>
                  navigate(`/family/${familyId}/queue/${queue.queue_id}`, {
                    state: { queue, groupId },
                  })
                }
                showCreatedDate={true}
                showStats={true}
              />
            ))}
          </div>
        ) : (
          <Empty
            image={Empty.PRESENTED_IMAGE_SIMPLE}
            description={
              <Space direction="vertical" size="small">
                <Text>No queues yet</Text>
                <Text type="secondary" style={{ fontSize: "12px" }}>
                  {isAdmin
                    ? "Create a queue to organize tickets"
                    : "Queues will appear here once created"}
                </Text>
              </Space>
            }
          />
        )}
      </Space>
    </Card>
  );

  const renderSettings = () => {
    if (!isAdmin) {
      return (
        <Card size="small">
          <Alert
            message="Admin Only"
            description="Only group admins can access group settings."
            type="info"
            showIcon
          />
        </Card>
      );
    }

    return (
      <Card
        size="small"
        title={
          <Space>
            <SettingOutlined />
            <span>Settings</span>
          </Space>
        }
      >
        <Space direction="vertical" size="middle" style={{ width: "100%" }}>
          <div>
            <Title level={5}>Edit Group</Title>
            <Paragraph type="secondary" style={{ fontSize: "13px" }}>
              Update the group name and description.
            </Paragraph>
            <Button
              type="primary"
              block
              icon={<EditOutlined />}
              onClick={showEditModal}
            >
              Edit Group
            </Button>
          </div>

          <div>
            <Title level={5} type="danger">
              Danger Zone
            </Title>
            <Paragraph type="secondary" style={{ fontSize: "13px" }}>
              Deleting a group is permanent and cannot be undone.
            </Paragraph>
            <Button
              danger
              block
              icon={<DeleteOutlined />}
              onClick={showDeleteModal}
            >
              Delete Group
            </Button>
          </div>
        </Space>
      </Card>
    );
  };

  const tabItems = [
    {
      key: "overview",
      label: "Overview",
      children: renderOverview(),
    },
    {
      key: "members",
      label: "Members",
      children: renderMembers(),
    },
    {
      key: "requests",
      label: (
        <span>
          Requests
          {requestCount > 0 && (
            <Tag color="orange" style={{ marginLeft: "4px", fontSize: "10px" }}>
              {requestCount}
            </Tag>
          )}
        </span>
      ),
      children: renderMembershipRequests(),
    },
    {
      key: "queues",
      label: (
        <span>
          Queues
          {queues && queues.length > 0 && (
            <Tag color="green" style={{ marginLeft: "4px", fontSize: "10px" }}>
              {queues.length}
            </Tag>
          )}
        </span>
      ),
      children: renderQueues(),
    },
    {
      key: "settings",
      label: "Settings",
      children: renderSettings(),
    },
  ];

  return (
    <div style={{ padding: "12px" }}>
      <div style={{ marginBottom: "12px" }}>
        <Button
          type="link"
          icon={<ArrowLeftOutlined />}
          onClick={() => navigate(`/family/${familyId}`)}
          style={{ paddingLeft: 0, fontSize: "15px", height: "44px" }}
        >
          Back
        </Button>
      </div>

      <Card size="small">
        <div style={{ marginBottom: "16px" }}>
          <Space direction="vertical" size="small" style={{ width: "100%" }}>
            <Title level={4} style={{ margin: 0 }}>
              {group.group_name}
            </Title>
            {group.group_description && (
              <Text type="secondary" style={{ fontSize: "13px" }}>
                {group.group_description}
              </Text>
            )}
            {isAdmin && (
              <Space size="small" style={{ width: "100%", marginTop: "8px" }}>
                <Button
                  size="middle"
                  icon={<EditOutlined />}
                  onClick={showEditModal}
                  block
                  style={{ height: "40px" }}
                >
                  Edit
                </Button>
                <Button
                  size="middle"
                  danger
                  icon={<DeleteOutlined />}
                  onClick={showDeleteModal}
                  block
                  style={{ height: "40px" }}
                >
                  Delete
                </Button>
              </Space>
            )}
          </Space>
        </div>

        <Tabs
          activeKey={activeTab}
          items={tabItems}
          onChange={handleTabChange}
          size="small"
        />
      </Card>

      {/* Edit Group Modal */}
      <EditGroupModal
        visible={isEditModalVisible}
        onClose={hideEditModal}
        group={group}
        onSuccess={() => {
          refetchGroups();
        }}
      />

      {/* Create Queue Modal */}
      <CreateQueueModal
        visible={isCreateQueueModalVisible}
        onClose={() => setIsCreateQueueModalVisible(false)}
        familyId={familyId}
        groupId={groupId}
        onSuccess={() => {
          queuesRefetch();
          setIsCreateQueueModalVisible(false);
          message.success("Queue created successfully");
        }}
      />

      {/* Delete Group Modal */}
      <Modal
        title="Delete Group"
        open={isDeleteModalVisible}
        onCancel={hideDeleteModal}
        footer={[
          <Button key="cancel" onClick={hideDeleteModal} block size="large">
            Cancel
          </Button>,
          <Button
            key="delete"
            type="primary"
            danger
            loading={isDeleting}
            onClick={handleDelete}
            block
            size="large"
          >
            Delete Group
          </Button>,
        ]}
      >
        <Alert
          message="Warning"
          description="This action cannot be undone. All queues and data will be permanently deleted."
          type="warning"
          showIcon
          style={{ marginBottom: "12px" }}
        />
        <Paragraph style={{ fontSize: "14px" }}>
          Are you sure you want to delete <strong>{group.group_name}</strong>?
        </Paragraph>
      </Modal>
    </div>
  );
};

export default GroupDetailMobile;
