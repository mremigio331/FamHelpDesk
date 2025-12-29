import React, { useContext } from "react";
import { Layout, Button, Avatar, Dropdown, Spin } from "antd";
import {
  UserOutlined,
  TagsOutlined,
  TeamOutlined,
  LoadingOutlined,
} from "@ant-design/icons";
import { useNavigate } from "react-router-dom";
import { UserAuthenticationContext } from "../provider/UserAuthenticationProvider";
import { useMyFamilies } from "../provider/MyFamiliesProvider";

const { Header } = Layout;

const Navbar = () => {
  const navigate = useNavigate();
  const { isAuthenticated } = useContext(UserAuthenticationContext);
  const { familiesArray, isFamiliesFetching } = useMyFamilies();

  const familiesMenuItems = [
    {
      key: "families-header",
      type: "group",
      label: "My Families",
    },
    ...(isFamiliesFetching
      ? [
          {
            key: "loading",
            label: (
              <div style={{ textAlign: "center", padding: "8px" }}>
                <Spin
                  indicator={<LoadingOutlined style={{ fontSize: 16 }} />}
                />
              </div>
            ),
            disabled: true,
          },
        ]
      : familiesArray.length === 0
        ? [
            {
              key: "no-families",
              label: "No families yet",
              disabled: true,
            },
          ]
        : familiesArray.map((item) => ({
            key: item.family.family_id,
            label: item.family.family_name,
            onClick: () => navigate(`/family/${item.family.family_id}`),
          }))),
    {
      type: "divider",
    },
    {
      key: "find-family",
      label: "Find a Family",
      onClick: () => navigate("/family/find"),
    },
    {
      key: "create-family",
      label: "Create Family",
      onClick: () => navigate("/family/create"),
    },
  ];

  return (
    <Header
      style={{
        position: "fixed",
        top: 0,
        zIndex: 1,
        width: "100%",
        display: "flex",
        alignItems: "center",
        justifyContent: "space-between",
        backgroundColor: "#001529",
        padding: "0 50px",
      }}
    >
      <div
        style={{
          display: "flex",
          alignItems: "center",
          gap: "12px",
          color: "white",
          fontSize: "20px",
          fontWeight: "bold",
          cursor: "pointer",
        }}
        onClick={() => navigate("/")}
      >
        <TagsOutlined style={{ fontSize: "24px" }} />
        <span>Fam Help Desk</span>
      </div>

      {isAuthenticated && (
        <div style={{ display: "flex", alignItems: "center", gap: "16px" }}>
          <Dropdown menu={{ items: familiesMenuItems }} placement="bottomRight">
            <Button
              type="text"
              icon={<TeamOutlined />}
              style={{ color: "white" }}
              className="families-button"
            >
              Families
            </Button>
          </Dropdown>

          <Button
            type="text"
            icon={<Avatar icon={<UserOutlined />} size="small" />}
            onClick={() => navigate("/profile")}
            style={{ color: "white" }}
          />
        </div>
      )}
      <style jsx>{`
        @media (max-width: 768px) {
          .families-button {
            display: none !important;
          }
        }
      `}</style>
    </Header>
  );
};

export default Navbar;
