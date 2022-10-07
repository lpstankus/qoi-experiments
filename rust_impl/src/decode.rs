use std::num::Wrapping;

pub struct Img {
    pub width: u32,
    pub height: u32,
    pub fmt: ImgFmt,
    pub data: Vec<u8>,
}

#[derive(Debug)]
pub enum DecodeError {
    MalformedHeader,
    MissingData,
    FailedToReadFile,
}

enum Optag {
    RGB,
    RGBA,
    INDEX,
    DIFF,
    LUMA,
    RUN,
}

pub enum ImgFmt {
    SRGB,
    SRGBA,
    LinearRGB,
    LinearRGBA,
}

type Pixel = [u8; 4];

const MAGIC: &[u8] = "qoif".as_bytes();

impl Img {
    pub fn from_path(path: &str) -> Result<Img, DecodeError> {
        let bytes = std::fs::read(path);
        match bytes {
            Ok(bytes) => Img::from_bytes(bytes),
            Err(_) => Err(DecodeError::FailedToReadFile),
        }
    }

    pub fn from_bytes(bytes: Vec<u8>) -> Result<Img, DecodeError> {
        if bytes.len() < 14 || &bytes[0..4] != MAGIC {
            return Err(DecodeError::MalformedHeader);
        }

        let width = pop_u32(&bytes[4..])?;
        let height = pop_u32(&bytes[8..])?;
        let (fmt, channels) = match (bytes[12], bytes[13]) {
            (3, 0) => (ImgFmt::SRGB, 3),
            (4, 0) => (ImgFmt::SRGBA, 3),
            (3, 1) => (ImgFmt::LinearRGB, 4),
            (4, 1) => (ImgFmt::LinearRGBA, 4),
            _ => return Err(DecodeError::MalformedHeader),
        };

        let mut data = vec![0; width as usize * height as usize * channels as usize];
        let mut running = vec![[0; 4]; 64];
        let mut prev_pixel = [0; 4];

        let mut di = 0;
        let mut bi = 14;
        while di < data.len() {
            assert_capacity(&bytes, bi)?;
            match bytes[bi].into() {
                Optag::RGB => {
                    assert_capacity(&bytes, bi + 3)?;
                    prev_pixel.copy_from_slice(&bytes[0..3]);
                    bi += 4;
                }
                Optag::RGBA => {
                    assert_capacity(&bytes, bi + 4)?;
                    prev_pixel.copy_from_slice(&bytes[0..4]);
                    bi += 5;
                }
                Optag::INDEX => {
                    prev_pixel = running[bytes[bi] as usize];
                    bi += 1;
                }
                Optag::DIFF => {
                    let r_diff = Wrapping((bytes[bi] >> 4) & 0b11) - Wrapping(2);
                    let g_diff = Wrapping((bytes[bi] >> 2) & 0b11) - Wrapping(2);
                    let b_diff = Wrapping((bytes[bi] >> 0) & 0b11) - Wrapping(2);
                    prev_pixel[0] = (Wrapping(prev_pixel[0]) + r_diff).0;
                    prev_pixel[1] = (Wrapping(prev_pixel[1]) + g_diff).0;
                    prev_pixel[2] = (Wrapping(prev_pixel[2]) + b_diff).0;
                    bi += 1
                }
                Optag::LUMA => {
                    assert_capacity(&bytes, bi + 2)?;
                    let g_diff = Wrapping(bytes[bi] & 0x3F) - Wrapping(32);
                    let r_diff = Wrapping((bytes[bi + 1] >> 4) & 0x0F) - Wrapping(8) + g_diff;
                    let b_diff = Wrapping((bytes[bi + 1] >> 0) & 0x0F) - Wrapping(8) + g_diff;
                    prev_pixel[0] = (Wrapping(prev_pixel[0]) + r_diff).0;
                    prev_pixel[1] = (Wrapping(prev_pixel[1]) + g_diff).0;
                    prev_pixel[2] = (Wrapping(prev_pixel[2]) + b_diff).0;
                    bi += 2;
                }
                Optag::RUN => {
                    let run = (bytes[bi] & 0x3F) as usize;
                    for _ in 0..run {
                        data[di + 0] = prev_pixel[0];
                        data[di + 1] = prev_pixel[1];
                        data[di + 2] = prev_pixel[2];
                        if channels == 4 {
                            data[di + 3] = prev_pixel[3];
                        }
                        di += channels as usize;
                    }
                    bi += 1;
                    di += run * channels as usize;
                    continue;
                }
            }
            running[hash(prev_pixel)] = prev_pixel;
            data[di + 0] = prev_pixel[0];
            data[di + 1] = prev_pixel[1];
            data[di + 2] = prev_pixel[2];
            if channels == 4 {
                data[di + 3] = prev_pixel[3];
            };
            di += channels as usize;
        }

        Ok(Img { width, height, fmt, data })
    }
}

impl From<u8> for Optag {
    fn from(val: u8) -> Self {
        match val {
            0xFE => Optag::RGB,
            0xFF => Optag::RGBA,
            _ => match val >> 6 {
                0 => Optag::INDEX,
                1 => Optag::DIFF,
                2 => Optag::LUMA,
                3 => Optag::RUN,
                _ => panic!(),
            },
        }
    }
}

#[inline]
fn assert_capacity(bytes: &[u8], i: usize) -> Result<(), DecodeError> {
    if i >= bytes.len() {
        Err(DecodeError::MissingData)
    } else {
        Ok(())
    }
}

#[inline]
fn pop_u32(slice: &[u8]) -> Result<u32, DecodeError> {
    Ok(u32::from_be_bytes(slice[0..4].try_into().map_err(|_| DecodeError::MalformedHeader)?))
}

#[inline]
fn hash(p: Pixel) -> usize {
    (p[0] as usize * 3 + p[1] as usize * 5 + p[2] as usize * 7 + p[3] as usize * 11) % 64
}
