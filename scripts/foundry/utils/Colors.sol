// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract Colors {
    /**
     * @dev Returns the red color of the text
     * @param text the text to color
     */
    function red(string memory text) public pure returns (string memory) {
        return string(abi.encodePacked("\x1b[31m", text, "\x1b[0m"));
    }

    /**
     * @dev Returns the green color of the text
     * @param text the text to color
     */
    function green(string memory text) public pure returns (string memory) {
        return string(abi.encodePacked("\x1b[32m", text, "\x1b[0m"));
    }

    /**
     * @dev Returns the yellow color of the text
     * @param text the text to color
     */
    function yellow(string memory text) public pure returns (string memory) {
        return string(abi.encodePacked("\x1b[33m", text, "\x1b[0m"));
    }

    /**
     * @dev Returns the blue color of the text
     * @param text the text to color
     */
    function blue(string memory text) public pure returns (string memory) {
        return string(abi.encodePacked("\x1b[34m", text, "\x1b[0m"));
    }

    /**
     * @dev Returns the magenta color of the text
     * @param text the text to color
     */
    function magenta(string memory text) public pure returns (string memory) {
        return string(abi.encodePacked("\x1b[35m", text, "\x1b[0m"));
    }

    /**
     * @dev Returns the cyan color of the text
     * @param text the text to color
     */
    function cyan(string memory text) public pure returns (string memory) {
        return string(abi.encodePacked("\x1b[36m", text, "\x1b[0m"));
    }

    /**
     * @dev Returns the white color of the text
     * @param text the text to color
     */
    function white(string memory text) public pure returns (string memory) {
        return string(abi.encodePacked("\x1b[37m", text, "\x1b[0m"));
    }

    /**
     * @dev Returns the black color of the text
     * @param text the text to color
     */
    function black(string memory text) public pure returns (string memory) {
        return string(abi.encodePacked("\x1b[30m", text, "\x1b[0m"));
    }
}
