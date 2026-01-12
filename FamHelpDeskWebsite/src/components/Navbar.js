import React, { useContext } from "react";
import { Layout, Button, Avatar, Dropdown, Spin, Badge } from "antd";
import {
  UserOutlined,
  TagsOutlined,
  TeamOutlined,
  LoadingOutlined,
  BellOutlined,
} from "@ant-design/icons";
import { useNavigate } from "react-router-dom";
import { UserAuthenticationContext } from "../provider/UserAuthenticationProvider";
import { useMyFamilies } from "../provider/MyFamiliesProvider";
import { useNotifications } from "../provider/NotificationsProvider";

const { Header } = Layout;

const Navbar = () => {
  const navigate = useNavigate();
  const { isAuthenticated } = useContext(UserAuthenticationContext);
  const { familiesArray, isFamiliesFetching } = useMyFamilies();
  const { unreadCount } = useNotifications();

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

  // Example: get user profile from localStorage or context (replace with actual logic)
  let userProfile = null;
  try {
    userProfile = JSON.parse(localStorage.getItem("user_profile"));
  } catch {}
  const profileColor = userProfile?.profile_color || "#001529";
  const darkModeWeb = userProfile?.dark_mode?.web || false;

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
        backgroundColor: darkModeWeb ? "#111" : profileColor,
        color: darkModeWeb ? "#eee" : "white",
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
            icon={
              <BellOutlined
                style={{
                  fontSize: "18px",
                  color: unreadCount > 0 ? "#ff4d4f" : "white",
                }}
              />
            }
            onClick={() => navigate("/notifications")}
          />

          <Button
            type="text"
            icon={
              <span
                style={{
                  display: "inline-flex",
                  alignItems: "center",
                  justifyContent: "center",
                  width: 32,
                  height: 32,
                  borderRadius: "50%",
                  backgroundColor: profileColor,
                  color: darkModeWeb ? "#eee" : "#fff",
                  fontWeight: "bold",
                  fontSize: "18px",
                  textTransform: "uppercase",
                  border: "2px solid #fff",
                  boxShadow: "0 0 2px rgba(0,0,0,0.1)",
                }}
              >
                {userProfile?.display_name?.[0] || <UserOutlined />}
              </span>
            }
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
