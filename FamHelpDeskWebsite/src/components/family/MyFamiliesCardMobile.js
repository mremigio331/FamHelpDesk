import React from "react";
import { Card, Space, Empty, Alert, Button } from "antd";
import { TeamOutlined, PlusOutlined, SearchOutlined } from "@ant-design/icons";
import { useNavigate } from "react-router-dom";
import { useMyFamilies } from "../../provider/MyFamiliesProvider";
import FamilyList from "./FamilyList";

const MyFamiliesCardMobile = () => {
  const navigate = useNavigate();
  const { familiesArray, isMyFamiliesError, myFamiliesError } = useMyFamilies();

  const families = familiesArray.map((item) => item.family);
  const memberships = familiesArray.reduce((acc, item) => {
    acc[item.family.family_id] = item.membership;
    return acc;
  }, {});

  return (
    <Card
      bodyStyle={{ padding: "12px" }}
      title={
        <Space size={6}>
          <TeamOutlined style={{ fontSize: "14px" }} />
          <span style={{ fontSize: "14px", fontWeight: "600" }}>
            My Families
          </span>
        </Space>
      }
      extra={
        <Space size={4}>
          <Button
            icon={<SearchOutlined />}
            onClick={() => navigate("/family/find")}
            size="small"
            style={{ fontSize: "11px" }}
          >
            Find
          </Button>
          <Button
            type="primary"
            icon={<PlusOutlined />}
            onClick={() => navigate("/family/create")}
            size="small"
            style={{ fontSize: "11px" }}
          >
            Create
          </Button>
        </Space>
      }
    >
      {isMyFamiliesError ? (
        <Alert
          message="Error loading families"
          description={
            myFamiliesError?.message || "Failed to load your families"
          }
          type="error"
          showIcon
          style={{ fontSize: "12px" }}
        />
      ) : familiesArray.length === 0 ? (
        <Empty
          description={
            <span style={{ fontSize: "12px" }}>
              You are not part of any families yet
            </span>
          }
          image={Empty.PRESENTED_IMAGE_SIMPLE}
        >
          <Space direction="vertical" size={4} style={{ width: "100%" }}>
            <Button
              type="primary"
              icon={<SearchOutlined />}
              onClick={() => navigate("/family/find")}
              size="small"
              block
              style={{ fontSize: "12px" }}
            >
              Find a Family
            </Button>
            <Button
              icon={<PlusOutlined />}
              onClick={() => navigate("/family/create")}
              size="small"
              block
              style={{ fontSize: "12px" }}
            >
              Create Family
            </Button>
          </Space>
        </Empty>
      ) : (
        <FamilyList
          families={families}
          memberships={memberships}
          onItemClick={(family) => navigate(`/family/${family.family_id}`)}
          emptyDescription="You are not part of any families yet"
        />
      )}
    </Card>
  );
};

export default MyFamiliesCardMobile;
