import React, { useContext } from "react";
import { Typography, Button } from "antd";
import { UserAuthenticationContext } from "../../provider/UserAuthenticationProvider";
import { jwtDecode } from "jwt-decode";

const { Title, Text } = Typography;

const HomeAuthenticated = () => {
  const { logoutUser, idToken } = useContext(UserAuthenticationContext);

  // Decode the ID token to get user info
  let userName = "User";
  let userEmail = "";

  if (idToken) {
    try {
      const decoded = jwtDecode(idToken);
      userName =
        decoded.name ||
        decoded["cognito:username"] ||
        decoded.username ||
        "User";
      userEmail = decoded.email || "";
    } catch (error) {
      console.error("Error decoding token:", error);
    }
  }

  return (
    <div style={{ padding: "50px" }}>
      <div style={{ textAlign: "center", maxWidth: "600px", margin: "0 auto" }}>
        <Title level={2}>Welcome to Fam Help Desk</Title>
        <div style={{ marginTop: "20px", marginBottom: "20px" }}>
          <Text style={{ fontSize: "18px" }}>
            Hello, <strong>{userName}</strong>!
          </Text>
          {userEmail && (
            <div style={{ marginTop: "10px" }}>
              <Text type="secondary">{userEmail}</Text>
            </div>
          )}
        </div>
        <div style={{ marginTop: "30px" }}>
          <Text>
            You are now signed in to the Fam Help Desk. Support features will be
            added here soon.
          </Text>
        </div>
        <div style={{ marginTop: "30px" }}>
          <Button type="primary" danger onClick={logoutUser}>
            Sign Out
          </Button>
        </div>
      </div>
    </div>
  );
};

export default HomeAuthenticated;
