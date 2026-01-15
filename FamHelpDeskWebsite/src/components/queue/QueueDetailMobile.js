import React, { useEffect, useState } from "react";
import { useParams, useNavigate, useLocation } from "react-router-dom";
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
  Statistic,
  Row,
  Col,
  Empty,
  Input,
  Select,
  Drawer,
} from "antd";
import {
  ArrowLeftOutlined,
  EditOutlined,
  DeleteOutlined,
  InboxOutlined,
  FileTextOutlined,
  SettingOutlined,
  SearchOutlined,
  FilterOutlined,
} from "@ant-design/icons";
import useQueueDetail from "./useQueueDetail";
import useGetQueues from "../../hooks/queue/useGetQueues";
import useDeleteQueue from "../../hooks/queue/useDeleteQueue";
import EditQueueModal from "./EditQueueModal";

const { Title, Text, Paragraph } = Typography;
const { Option } = Select;

const QueueDetailMobile = () => {
  const { familyId, queueId } = useParams();
  const navigate = useNavigate();
  const location = useLocation();

  // Get queue and groupId from navigation state if available
  const passedQueue = location.state?.queue;
  const passedGroupId = location.state?.groupId;

  const {
    activeTab,
    handleTabChange,
    isEditModalVisible,
    showEditModal,
    hideEditModal,
    isDeleteModalVisible,
    showDeleteModal,
    hideDeleteModal,
  } = useQueueDetail();

  const { queues, isQueuesFetching, isQueuesError, queuesRefetch } =
    useGetQueues(familyId, passedGroupId, !!passedGroupId);

  const { deleteQueue, isDeleting, isDeleteSuccess } = useDeleteQueue();

  // Ticket filtering state
  const [ticketSearchQuery, setTicketSearchQuery] = useState("");
  const [ticketStatusFilter, setTicketStatusFilter] = useState("all");
  const [isFilterDrawerVisible, setIsFilterDrawerVisible] = useState(false);

  // Use passed queue if available, otherwise find from fetched queues
  const queue = passedQueue || queues?.find((q) => q.queue_id === queueId);

  // Handle successful operations
  useEffect(() => {
    if (isDeleteSuccess) {
      message.success("Queue deleted successfully");
      // Navigate back to the group detail page
      if (queue?.group_id) {
        navigate(`/family/${familyId}/group/${queue.group_id}`);
      } else {
        navigate(`/family/${familyId}`);
      }
    }
  }, [isDeleteSuccess, navigate, familyId, queue]);

  const handleDelete = async () => {
    try {
      await deleteQueue({
        family_id: familyId,
        queue_id: queueId,
      });
    } catch (error) {
      message.error("Failed to delete queue");
      hideDeleteModal();
    }
  };

  const handleBackNavigation = () => {
    if (queue?.group_id) {
      navigate(`/family/${familyId}/group/${queue.group_id}`);
    } else {
      navigate(`/family/${familyId}`);
    }
  };

  if (!passedQueue && isQueuesFetching) {
    return (
      <div style={{ padding: "50px", textAlign: "center" }}>
        <Spin size="large" />
      </div>
    );
  }

  if (!passedQueue && (isQueuesError || !queue)) {
    return (
      <div style={{ padding: "16px" }}>
        <Alert
          message="Queue Not Found"
          description="This queue does not exist or you don't have access to it."
          type="warning"
          showIcon
          action={
            <Button type="primary" onClick={handleBackNavigation} block>
              Back
            </Button>
          }
        />
      </div>
    );
  }

  const renderOverview = () => (
    <div style={{ padding: "16px" }}>
      <Space direction="vertical" size="middle" style={{ width: "100%" }}>
        <Card size="small">
          <Title level={5}>Queue Information</Title>
          <Descriptions column={1} size="small">
            <Descriptions.Item label="Name">
              {queue.queue_name}
            </Descriptions.Item>
            <Descriptions.Item label="Description">
              {queue.queue_description || "No description"}
            </Descriptions.Item>
            <Descriptions.Item label="Created">
              {new Date(queue.creation_date * 1000).toLocaleDateString()}
            </Descriptions.Item>
          </Descriptions>
        </Card>

        <Card size="small">
          <Title level={5}>Statistics</Title>
          <Row gutter={[8, 8]}>
            <Col span={12}>
              <Card size="small">
                <Statistic
                  title="Open"
                  value={queue.open_ticket_count || 0}
                  prefix={<FileTextOutlined />}
                  valueStyle={{ fontSize: "20px", color: "#1890ff" }}
                />
              </Card>
            </Col>
            <Col span={12}>
              <Card size="small">
                <Statistic
                  title="Total"
                  value={queue.total_ticket_count || 0}
                  prefix={<FileTextOutlined />}
                  valueStyle={{ fontSize: "20px" }}
                />
              </Card>
            </Col>
          </Row>
        </Card>
      </Space>
    </div>
  );

  const renderTickets = () => (
    <div style={{ padding: "16px" }}>
      <Space
        direction="vertical"
        size="middle"
        style={{ width: "100%", marginBottom: "16px" }}
      >
        <Input
          placeholder="Search tickets..."
          prefix={<SearchOutlined />}
          value={ticketSearchQuery}
          onChange={(e) => setTicketSearchQuery(e.target.value)}
          allowClear
        />
        <Button
          icon={<FilterOutlined />}
          onClick={() => setIsFilterDrawerVisible(true)}
          block
        >
          Filter:{" "}
          {ticketStatusFilter === "all" ? "All Tickets" : ticketStatusFilter}
        </Button>
      </Space>

      <Empty
        image={Empty.PRESENTED_IMAGE_SIMPLE}
        description={
          <Space direction="vertical" size="small">
            <Text>No tickets in this queue yet</Text>
            <Text type="secondary" style={{ fontSize: "12px" }}>
              Tickets will appear here once they are created
            </Text>
          </Space>
        }
      />

      {/* Filter Drawer */}
      <Drawer
        title="Filter Tickets"
        placement="bottom"
        height="auto"
        open={isFilterDrawerVisible}
        onClose={() => setIsFilterDrawerVisible(false)}
      >
        <Space direction="vertical" size="middle" style={{ width: "100%" }}>
          <div>
            <Text strong>Status</Text>
            <Select
              value={ticketStatusFilter}
              onChange={(value) => {
                setTicketStatusFilter(value);
                setIsFilterDrawerVisible(false);
              }}
              style={{ width: "100%", marginTop: "8px" }}
            >
              <Option value="all">All Tickets</Option>
              <Option value="open">Open</Option>
              <Option value="in_progress">In Progress</Option>
              <Option value="resolved">Resolved</Option>
              <Option value="closed">Closed</Option>
            </Select>
          </div>
        </Space>
      </Drawer>
    </div>
  );

  const renderSettings = () => (
    <div style={{ padding: "16px" }}>
      <Space direction="vertical" size="middle" style={{ width: "100%" }}>
        <Card size="small">
          <Title level={5}>Edit Queue</Title>
          <Paragraph type="secondary" style={{ fontSize: "12px" }}>
            Update the queue name and description.
          </Paragraph>
          <Button
            type="primary"
            icon={<EditOutlined />}
            onClick={showEditModal}
            block
          >
            Edit Queue
          </Button>
        </Card>

        <Card size="small">
          <Title level={5} type="danger">
            Danger Zone
          </Title>
          <Paragraph type="secondary" style={{ fontSize: "12px" }}>
            Deleting a queue is permanent and cannot be undone.
          </Paragraph>
          <Button
            danger
            icon={<DeleteOutlined />}
            onClick={showDeleteModal}
            block
          >
            Delete Queue
          </Button>
        </Card>
      </Space>
    </div>
  );

  const tabItems = [
    {
      key: "overview",
      label: "Overview",
      children: renderOverview(),
    },
    {
      key: "tickets",
      label: (
        <span>
          Tickets
          {queue.open_ticket_count > 0 && (
            <Tag color="blue" style={{ marginLeft: "4px" }}>
              {queue.open_ticket_count}
            </Tag>
          )}
        </span>
      ),
      children: renderTickets(),
    },
    {
      key: "settings",
      label: "Settings",
      children: renderSettings(),
    },
  ];

  return (
    <div style={{ paddingBottom: "16px" }}>
      {/* Header */}
      <div
        style={{
          padding: "16px",
          background: "#fff",
          borderBottom: "1px solid #f0f0f0",
          position: "sticky",
          top: 0,
          zIndex: 10,
        }}
      >
        <Button
          type="link"
          icon={<ArrowLeftOutlined />}
          onClick={handleBackNavigation}
          style={{ paddingLeft: 0, marginBottom: "8px" }}
        >
          Back
        </Button>
        <Title level={4} style={{ margin: 0 }}>
          {queue.queue_name}
        </Title>
        {queue.queue_description && (
          <Text type="secondary" style={{ fontSize: "12px" }}>
            {queue.queue_description}
          </Text>
        )}
      </div>

      {/* Tabs */}
      <Tabs
        activeKey={activeTab}
        items={tabItems}
        onChange={handleTabChange}
        style={{ background: "#fff" }}
      />

      {/* Edit Queue Modal */}
      <EditQueueModal
        visible={isEditModalVisible}
        onClose={hideEditModal}
        queue={queue}
        onSuccess={() => {
          queuesRefetch();
        }}
      />

      {/* Delete Queue Modal */}
      <Modal
        title="Delete Queue"
        open={isDeleteModalVisible}
        onCancel={hideDeleteModal}
        footer={[
          <Button key="cancel" onClick={hideDeleteModal} block>
            Cancel
          </Button>,
          <Button
            key="delete"
            type="primary"
            danger
            loading={isDeleting}
            onClick={handleDelete}
            block
            style={{ marginTop: "8px" }}
          >
            Delete Queue
          </Button>,
        ]}
      >
        <Alert
          message="Warning"
          description="This action cannot be undone."
          type="warning"
          showIcon
          style={{ marginBottom: "16px" }}
        />
        <Paragraph>
          Are you sure you want to delete <strong>{queue.queue_name}</strong>?
        </Paragraph>
      </Modal>
    </div>
  );
};

export default QueueDetailMobile;
