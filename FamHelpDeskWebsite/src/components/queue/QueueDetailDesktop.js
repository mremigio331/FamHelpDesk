import React, { useEffect, useState } from "react";
import { useParams, useNavigate, useLocation } from "react-router-dom";
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
  Statistic,
  Row,
  Col,
  Empty,
  Input,
  Select,
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

const QueueDetailDesktop = () => {
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
      <div style={{ padding: "50px", maxWidth: "600px", margin: "0 auto" }}>
        <Alert
          message="Queue Not Found"
          description="This queue does not exist or you don't have access to it."
          type="warning"
          showIcon
          action={
            <Button type="primary" onClick={handleBackNavigation}>
              Back
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
          <Title level={3}>Queue Information</Title>
          <Descriptions bordered column={1}>
            <Descriptions.Item label="Name">
              {queue.queue_name}
            </Descriptions.Item>
            <Descriptions.Item label="Description">
              {queue.queue_description || "No description"}
            </Descriptions.Item>
            <Descriptions.Item label="Created">
              {new Date(queue.creation_date * 1000).toLocaleDateString()}
            </Descriptions.Item>
            <Descriptions.Item label="Created By">
              {queue.created_by || "Unknown"}
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
                  value={queue.open_ticket_count || 0}
                  prefix={<FileTextOutlined />}
                  valueStyle={{ color: "#1890ff" }}
                />
              </Card>
            </Col>
            <Col span={12}>
              <Card>
                <Statistic
                  title="Total Tickets"
                  value={queue.total_ticket_count || 0}
                  prefix={<FileTextOutlined />}
                />
              </Card>
            </Col>
          </Row>
        </div>
      </Space>
    </Card>
  );

  const renderTickets = () => (
    <Card
      title={
        <Space>
          <FileTextOutlined />
          <span>Tickets</span>
        </Space>
      }
    >
      <Space
        direction="vertical"
        size="middle"
        style={{ width: "100%", marginBottom: "16px" }}
      >
        <Space style={{ width: "100%" }}>
          <Input
            placeholder="Search tickets..."
            prefix={<SearchOutlined />}
            value={ticketSearchQuery}
            onChange={(e) => setTicketSearchQuery(e.target.value)}
            style={{ width: "300px" }}
            allowClear
          />
          <Select
            value={ticketStatusFilter}
            onChange={setTicketStatusFilter}
            style={{ width: "150px" }}
            suffixIcon={<FilterOutlined />}
          >
            <Option value="all">All Tickets</Option>
            <Option value="open">Open</Option>
            <Option value="in_progress">In Progress</Option>
            <Option value="resolved">Resolved</Option>
            <Option value="closed">Closed</Option>
          </Select>
        </Space>
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
    </Card>
  );

  const renderSettings = () => (
    <Card
      title={
        <Space>
          <SettingOutlined />
          <span>Queue Settings</span>
        </Space>
      }
    >
      <Space direction="vertical" size="large" style={{ width: "100%" }}>
        <div>
          <Title level={5}>Edit Queue</Title>
          <Paragraph type="secondary">
            Update the queue name and description.
          </Paragraph>
          <Button
            type="primary"
            icon={<EditOutlined />}
            onClick={showEditModal}
          >
            Edit Queue
          </Button>
        </div>

        <div>
          <Title level={5} type="danger">
            Danger Zone
          </Title>
          <Paragraph type="secondary">
            Deleting a queue is permanent and cannot be undone. All tickets
            associated with this queue will need to be reassigned or closed.
          </Paragraph>
          <Button danger icon={<DeleteOutlined />} onClick={showDeleteModal}>
            Delete Queue
          </Button>
        </div>
      </Space>
    </Card>
  );

  const tabItems = [
    {
      key: "overview",
      label: (
        <span>
          <InboxOutlined />
          Overview
        </span>
      ),
      children: renderOverview(),
    },
    {
      key: "tickets",
      label: (
        <span>
          <FileTextOutlined />
          Tickets
          {queue.open_ticket_count > 0 && (
            <Tag color="blue" style={{ marginLeft: "8px" }}>
              {queue.open_ticket_count}
            </Tag>
          )}
        </span>
      ),
      children: renderTickets(),
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
            onClick={handleBackNavigation}
            style={{ paddingLeft: 0 }}
          >
            Back to Group
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
                  {queue.queue_name}
                </Title>
                {queue.queue_description && (
                  <Text type="secondary">{queue.queue_description}</Text>
                )}
              </div>
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
            </Space>
          </div>

          <Tabs
            activeKey={activeTab}
            items={tabItems}
            onChange={handleTabChange}
          />
        </Card>

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
              Delete Queue
            </Button>,
          ]}
        >
          <Alert
            message="Warning"
            description="This action cannot be undone. All tickets in this queue will need to be reassigned or closed before deletion."
            type="warning"
            showIcon
            style={{ marginBottom: "16px" }}
          />
          <Paragraph>
            Are you sure you want to delete <strong>{queue.queue_name}</strong>?
          </Paragraph>
        </Modal>
      </div>
    </div>
  );
};

export default QueueDetailDesktop;
