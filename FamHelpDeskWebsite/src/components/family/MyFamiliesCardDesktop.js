import React from "react";
import { Card, Space, Empty, Alert, Button } from "antd";
import { TeamOutlined, PlusOutlined, SearchOutlined } from "@ant-design/icons";
import { useNavigate } from "react-router-dom";
import { useMyFamilies } from "../../provider/MyFamiliesProvider";
import FamilyList from "./FamilyList";

const MyFamiliesCardDesktop = () => {
  const navigate = useNavigate();
  const { familiesArray, isMyFamiliesError, myFamiliesError } = useMyFamilies();

  const families = familiesArray.map((item) => item.family);
  const memberships = familiesArray.reduce((acc, item) => {
    acc[item.family.family_id] = item.membership;
    return acc;
  }, {});

  return (
    <Card
      title={
        <Space>
          <TeamOutlined />
          <span>My Families</span>
        </Space>
      }
      extra={
        <Space>
          <Button
            icon={<SearchOutlined />}
            onClick={() => navigate("/family/find")}
          >
            Find Family
          </Button>
          <Button
            type="primary"
            icon={<PlusOutlined />}
            onClick={() => navigate("/family/create")}
          >
            Create Family
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
        />
      ) : familiesArray.length === 0 ? (
        <Empty
          description="You are not part of any families yet"
          image={Empty.PRESENTED_IMAGE_SIMPLE}
        >
          <Space>
            <Button
              type="primary"
              icon={<SearchOutlined />}
              onClick={() => navigate("/family/find")}
            >
              Find a Family
            </Button>
            <Button
              icon={<PlusOutlined />}
              onClick={() => navigate("/family/create")}
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

export default MyFamiliesCardDesktop;
