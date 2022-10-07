struct Img {
    pub width: u32,
    pub height: u32,
    pub channels: u8,
    pub colorspace: Colorspace,
    pub data: Vec<u8>,
}
