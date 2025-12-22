import React, { useContext } from "react";
import HomeAuthenticated from "./HomeAuthenticated";
import HomeUnauthenticated from "./HomeUnauthenticated";
import { UserAuthenticationContext } from "../../provider/UserAuthenticationProvider";

const Home = () => {
  const { isAuthenticated } = useContext(UserAuthenticationContext);

  return isAuthenticated ? <HomeAuthenticated /> : <HomeUnauthenticated />;
};

export default Home;
