import React, { useEffect } from "react";
import { useParams, useNavigate } from "react-router-dom";
import {
  Layout,
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
} from "@ant-design/icons";
import useGroupDetail from "./useGroupDetail";
import useGroups from "../../hooks/group/useGroups";
import useGetGroupMembers from "../../hooks/group/membership/useGetGroupMembers";
import useGetGroupMembershipRequests from "../../hooks/group/membership/useGetGroupMembershipRequests";
import useReviewGroupMembership from "../../hooks/group/membership/useReviewGroupMembership";
import useRemoveGroupMember from "../../hooks/group/membership/useRemoveGroupMember";
import useUpdateGroupMemberRole from "../../hooks/group/membership/useUpdateGroupMemberRole";
import useGetQueues from "../../hooks/queue/useGetQueues";
import useDeleteQueue from "../../hooks/queue/useDeleteQueue";
import EditGroupModal from "./EditGroupModal";
import QueueList from "../queue/QueueList";
import CreateQueueModal from "../queue/CreateQueueModal";

const { Title, Text, Paragraph } = Typography;

const GroupDetailDesktop = () => {
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
    isCreateQueueModalVisible,
    showCreateQueueModal,
    hideCreateQueueModal,
    selectedQueue,
    selectQueue,
    clearSelectedQueue,
  } = useGroupDetail();

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

  const { queues, isQueuesFetching, isQueuesError, queuesRefetch } =
    useGetQueues(familyId, groupId);

  const {
    deleteQueue,
    isDeleting: isDeletingQueue,
    isDeleteSuccess: isQueueDeleteSuccess,
  } = useDeleteQueue();

  // Find the current group
  const group = allGroups?.find((g) => g.group_id === groupId);
  const currentUserMembership = members?.find(
    (m) => m.is_current_user === true,
  );
  const isAdmin = currentUserMembership?.is_admin === true;

  // Debug logging
  console.log("GroupDetailDesktop Debug:", {
    members,
    currentUserMembership,
    isAdmin,
  });

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

  useEffect(() => {
    if (isQueueDeleteSuccess) {
      message.success("Queue deleted successfully");
      queuesRefetch();
      clearSelectedQueue();
    }
  }, [isQueueDeleteSuccess, queuesRefetch, clearSelectedQueue]);

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

  const handleDeleteQueue = async (queueId) => {
    try {
      await deleteQueue({
        family_id: familyId,
        queue_id: queueId,
      });
    } catch (error) {
      message.error("Failed to delete queue");
    }
  };

  const handleQueueClick = (queue) => {
    selectQueue(queue);
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
      <div style={{ padding: "50px", maxWidth: "600px", margin: "0 auto" }}>
        <Alert
          message="Group Not Found"
          description="This group does not exist or you don't have access to it."
          type="warning"
          showIcon
          action={
            <Button
              type="primary"
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
    <Card>
      <Space direction="vertical" size="large" style={{ width: "100%" }}>
        <div>
          <Title level={3}>Group Information</Title>
          <Descriptions bordered column={1}>
            <Descriptions.Item label="Name">
              {group.group_name}
            </Descriptions.Item>
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
        </div>

        <div>
          <Title level={4}>Statistics</Title>
          <Row gutter={16}>
            <Col span={8}>
              <Card>
                <Statistic
                  title="Members"
                  value={memberCount}
                  prefix={<UserOutlined />}
                />
              </Card>
            </Col>
            <Col span={8}>
              <Card>
                <Statistic
                  title="Queues"
                  value={group.queue_count || 0}
                  prefix={<InboxOutlined />}
                />
              </Card>
            </Col>
            <Col span={8}>
              <Card>
                <Statistic
                  title="Pending Requests"
                  value={requestCount}
                  prefix={<UserAddOutlined />}
                />
              </Card>
            </Col>
          </Row>
        </div>
      </Space>
    </Card>
  );

  const renderMembers = () => (
    <Card
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
          dataSource={members}
          renderItem={(member) => (
            <List.Item
              actions={
                isAdmin && !member.is_current_user
                  ? [
                      <Button
                        key="toggle-admin"
                        type="link"
                        icon={<CrownOutlined />}
                        onClick={() =>
                          handleToggleAdmin(member.user_id, member.is_admin)
                        }
                        loading={isUpdatingRole}
                      >
                        {member.is_admin ? "Remove Admin" : "Make Admin"}
                      </Button>,
                      <Popconfirm
                        key="remove"
                        title="Remove this member?"
                        description="Are you sure you want to remove this member from the group?"
                        onConfirm={() => handleRemoveMember(member.user_id)}
                        okText="Yes"
                        cancelText="No"
                      >
                        <Button
                          type="link"
                          danger
                          icon={<UserDeleteOutlined />}
                          loading={isRemovingMember}
                        >
                          Remove
                        </Button>
                      </Popconfirm>,
                    ]
                  : []
              }
            >
              <List.Item.Meta
                avatar={<Avatar icon={<UserOutlined />} />}
                title={
                  <Space>
                    <span>{member.user_display_name || member.user_email}</span>
                    {member.is_admin && (
                      <Tag color="blue" icon={<CrownOutlined />}>
                        Admin
                      </Tag>
                    )}
                    {member.is_current_user && <Tag color="green">You</Tag>}
                  </Space>
                }
                description={member.user_email}
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
        <Card>
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
        title={
          <Space>
            <UserAddOutlined />
            <span>Membership Requests ({requestCount})</span>
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
            description="There are no pending membership requests at this time."
            type="info"
            showIcon
          />
        ) : (
          <List
            dataSource={requests}
            renderItem={(request) => (
              <List.Item
                actions={[
                  <Button
                    key="approve"
                    type="primary"
                    onClick={() => handleApproveRequest(request.user_id)}
                    loading={isReviewingMembership}
                  >
                    Approve
                  </Button>,
                  <Button
                    key="reject"
                    danger
                    onClick={() => handleRejectRequest(request.user_id)}
                    loading={isReviewingMembership}
                  >
                    Reject
                  </Button>,
                ]}
              >
                <List.Item.Meta
                  avatar={<Avatar icon={<UserOutlined />} />}
                  title={request.user_display_name || request.user_email}
                  description={
                    <Space direction="vertical" size="small">
                      <Text type="secondary">{request.user_email}</Text>
                      <Text type="secondary" style={{ fontSize: "12px" }}>
                        Requested:{" "}
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
    <Card
      title={
        <Space>
          <InboxOutlined />
          <span>Queues ({queues?.length || 0})</span>
        </Space>
      }
      extra={
        isAdmin && (
          <Button
            type="primary"
            icon={<InboxOutlined />}
            onClick={showCreateQueueModal}
          >
            Create Queue
          </Button>
        )
      }
    >
      {isQueuesFetching ? (
        <div style={{ textAlign: "center", padding: "20px" }}>
          <Spin />
        </div>
      ) : isQueuesError ? (
        <Alert
          message="Error"
          description="Failed to load queues"
          type="error"
          showIcon
        />
      ) : (
        <QueueList
          queues={queues || []}
          onItemClick={handleQueueClick}
          renderActions={
            isAdmin
              ? (queue) => [
                  <Popconfirm
                    key="delete"
                    title="Delete this queue?"
                    description="Are you sure you want to delete this queue? This action cannot be undone."
                    onConfirm={() => handleDeleteQueue(queue.queue_id)}
                    okText="Yes"
                    cancelText="No"
                  >
                    <Button
                      type="link"
                      danger
                      icon={<DeleteOutlined />}
                      loading={isDeletingQueue}
                    >
                      Delete
                    </Button>
                  </Popconfirm>,
                ]
              : null
          }
          emptyDescription="No queues in this group yet"
          showCreatedDate={true}
          showStats={true}
        />
      )}
    </Card>
  );

  const renderSettings = () => {
    if (!isAdmin) {
      return (
        <Card>
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
        title={
          <Space>
            <SettingOutlined />
            <span>Group Settings</span>
          </Space>
        }
      >
        <Space direction="vertical" size="large" style={{ width: "100%" }}>
          <div>
            <Title level={5}>Edit Group</Title>
            <Paragraph type="secondary">
              Update the group name and description.
            </Paragraph>
            <Button
              type="primary"
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
            <Paragraph type="secondary">
              Deleting a group is permanent and cannot be undone. All queues and
              data associated with this group will be removed.
            </Paragraph>
            <Button danger icon={<DeleteOutlined />} onClick={showDeleteModal}>
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
      label: (
        <span>
          <TeamOutlined />
          Overview
        </span>
      ),
      children: renderOverview(),
    },
    {
      key: "members",
      label: (
        <span>
          <UserOutlined />
          Members
        </span>
      ),
      children: renderMembers(),
    },
    {
      key: "requests",
      label: (
        <span>
          <UserAddOutlined />
          Requests
          {requestCount > 0 && (
            <Tag color="orange" style={{ marginLeft: "8px" }}>
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
          <InboxOutlined />
          Queues
        </span>
      ),
      children: renderQueues(),
    },
    {
      key: "settings",
      label: (
        <span>
          <SettingOutlined />
          Settings
        </span>
      ),
      children: renderSettings(),
    },
  ];

  return (
    <div style={{ padding: "24px" }}>
      <div style={{ maxWidth: "1200px", margin: "0 auto" }}>
        <div style={{ marginBottom: "24px" }}>
          <Button
            type="link"
            icon={<ArrowLeftOutlined />}
            onClick={() => navigate(`/family/${familyId}`)}
            style={{ paddingLeft: 0 }}
          >
            Back to Family
          </Button>
        </div>

        <Card>
          <div style={{ marginBottom: "24px" }}>
            <Space
              align="center"
              style={{ width: "100%", justifyContent: "space-between" }}
            >
              <div>
                <Title level={2} style={{ margin: 0 }}>
                  {group.group_name}
                </Title>
                {group.group_description && (
                  <Text type="secondary">{group.group_description}</Text>
                )}
              </div>
              {isAdmin && (
                <Space>
                  <Button icon={<EditOutlined />} onClick={showEditModal}>
                    Edit
                  </Button>
                  <Button
                    danger
                    icon={<DeleteOutlined />}
                    onClick={showDeleteModal}
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

        {/* Delete Group Modal */}
        <Modal
          title="Delete Group"
          open={isDeleteModalVisible}
          onCancel={hideDeleteModal}
          footer={[
            <Button key="cancel" onClick={hideDeleteModal}>
              Cancel
            </Button>,
            <Button
              key="delete"
              type="primary"
              danger
              loading={isDeleting}
              onClick={handleDelete}
            >
              Delete Group
            </Button>,
          ]}
        >
          <Alert
            message="Warning"
            description="This action cannot be undone. All queues and data associated with this group will be permanently deleted."
            type="warning"
            showIcon
            style={{ marginBottom: "16px" }}
          />
          <Paragraph>
            Are you sure you want to delete <strong>{group.group_name}</strong>?
          </Paragraph>
        </Modal>

        {/* Create Queue Modal */}
        <CreateQueueModal
          visible={isCreateQueueModalVisible}
          onClose={hideCreateQueueModal}
          familyId={familyId}
          groupId={groupId}
          onSuccess={() => {
            queuesRefetch();
          }}
        />

        {/* Queue Detail Drawer */}
        <Drawer
          title={selectedQueue?.queue_name}
          placement="right"
          width={720}
          onClose={clearSelectedQueue}
          open={!!selectedQueue}
        >
          {selectedQueue && (
            <Space direction="vertical" size="large" style={{ width: "100%" }}>
              <div>
                <Title level={4}>Queue Information</Title>
                <Descriptions bordered column={1} size="small">
                  <Descriptions.Item label="Name">
                    {selectedQueue.queue_name}
                  </Descriptions.Item>
                  <Descriptions.Item label="Description">
                    {selectedQueue.queue_description || "No description"}
                  </Descriptions.Item>
                  <Descriptions.Item label="Created">
                    {new Date(
                      selectedQueue.creation_date * 1000,
                    ).toLocaleDateString()}
                  </Descriptions.Item>
                </Descriptions>
              </div>

              <div>
                <Title level={4}>Statistics</Title>
                <Row gutter={16}>
                  <Col span={12}>
                    <Card>
                      <Statistic
                        title="Open Tickets"
                        value={selectedQueue.open_ticket_count || 0}
                        prefix={<InboxOutlined />}
                        valueStyle={{ color: "#1890ff" }}
                      />
                    </Card>
                  </Col>
                  <Col span={12}>
                    <Card>
                      <Statistic
                        title="Total Tickets"
                        value={selectedQueue.total_ticket_count || 0}
                        prefix={<InboxOutlined />}
                      />
                    </Card>
                  </Col>
                </Row>
              </div>

              {isAdmin && (
                <div>
                  <Title level={4}>Actions</Title>
                  <Space>
                    <Button
                      type="primary"
                      icon={<EditOutlined />}
                      onClick={() => {
                        // TODO: Open edit modal for selected queue
                        message.info("Edit queue functionality coming soon");
                      }}
                    >
                      Edit Queue
                    </Button>
                    <Popconfirm
                      title="Delete this queue?"
                      description="Are you sure you want to delete this queue? This action cannot be undone."
                      onConfirm={() =>
                        handleDeleteQueue(selectedQueue.queue_id)
                      }
                      okText="Yes"
                      cancelText="No"
                    >
                      <Button
                        danger
                        icon={<DeleteOutlined />}
                        loading={isDeletingQueue}
                      >
                        Delete Queue
                      </Button>
                    </Popconfirm>
                  </Space>
                </div>
              )}
            </Space>
          )}
        </Drawer>
      </div>
    </div>
  );
};

export default GroupDetailDesktop;
