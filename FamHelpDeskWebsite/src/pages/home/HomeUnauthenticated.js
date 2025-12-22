import React, { useContext } from "react";
import { Button, Typography } from "antd";
import { UserAuthenticationContext } from "../../provider/UserAuthenticationProvider";

const { Title, Text } = Typography;

const HomeUnauthenticated = () => {
  const { initiateSignIn, initiateSignUp } = useContext(
    UserAuthenticationContext,
  );

  return (
    <div
      style={{
        textAlign: "center",
        paddingTop: "64px",
        height: "100vh",
        display: "flex",
        flexDirection: "column",
        justifyContent: "flex-start",
        alignItems: "center",
        width: "100%",
        margin: 0,
      }}
    >
      <div
        style={{
          display: "flex",
          flexDirection: "column",
          justifyContent: "flex-start",
          alignItems: "center",
          padding: "0",
        }}
      >
        <Title
          level={1}
          style={{
            fontSize: 48,
            marginTop: 8,
            marginBottom: 8,
          }}
        >
          Fam Help Desk
        </Title>
        <Title
          level={2}
          style={{
            fontSize: 22,
            marginTop: 8,
            fontWeight: "normal",
          }}
        >
          Welcome to the Fam Help Desk
        </Title>
        <Text style={{ marginTop: 16 }}>Let's get you signed in</Text>
        <div
          style={{
            marginTop: "20px",
            display: "flex",
            justifyContent: "center",
            gap: 12,
          }}
        >
          <Button type="primary" size="large" onClick={initiateSignIn}>
            Sign In
          </Button>
          <Button type="default" size="large" onClick={initiateSignUp}>
            Sign Up
          </Button>
        </div>
      </div>
    </div>
  );
};

export default HomeUnauthenticated;
