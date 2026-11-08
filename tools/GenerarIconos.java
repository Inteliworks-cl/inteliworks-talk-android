// Genera los recursos graficos de Inteliworks Talk a partir de branding/source/icono.png
// (logo azul sobre circulo blanco, fondo transparente, 512x512).
// Adaptado de inteliworks-cloud-android: mismos tratamientos, nombres de recursos de Nextcloud Talk.
// Uso: java tools/GenerarIconos.java branding/source/icono.png branding/res
// SPDX-License-Identifier: GPL-3.0-or-later
import javax.imageio.ImageIO;
import java.awt.*;
import java.awt.image.BufferedImage;
import java.io.File;

public class GenerarIconos {
    static BufferedImage src;

    public static void main(String[] a) throws Exception {
        src = ImageIO.read(new File(a[0]));
        File res = new File(a[1]);
        BufferedImage disc = crop(src, alphaBox(src, 10));      // circulo blanco con logo
        BufferedImage mark = toMark(src);                         // solo el logo (alpha)
        mark = crop(mark, alphaBox(mark, 10));

        // Talk usa estos drawables tambien desde Compose (painterResource), que solo acepta
        // vectores o bitmaps: por eso son PNG directos (no <inset>), y apply.sh borra los XML upstream.
        // Foreground adaptativo 108dp => 432px @xxxhdpi; circulo en zona segura (66dp = 264px)
        write(center(disc, 432, 264), res, "drawable-xxxhdpi/ic_launcher_foreground.png");
        // Monocromo (Android 13 temas): solo la silueta del logo
        write(center(tint(mark, Color.WHITE), 432, 230), res, "drawable-xxxhdpi/ic_launcher_monochrome.png");
        // Logo de pantalla de servidor / splash (sobre fondo azul de marca)
        write(scale(disc, 512), res, "drawable-xxxhdpi/ic_logo.png");
        // Icono de notificacion (silueta blanca, 24dp => 96px @xxxhdpi)
        write(center(tint(mark, Color.WHITE), 96, 84), res, "drawable-xxxhdpi/ic_notification.png");
        // Iconos legacy (mipmap) por densidad: circulo blanco sobre fondo de marca
        int[] px = {48, 72, 96, 144, 192};
        String[] d = {"mdpi", "hdpi", "xhdpi", "xxhdpi", "xxxhdpi"};
        for (int i = 0; i < px.length; i++) {
            write(legacy(disc, px[i]), res, "mipmap-" + d[i] + "/ic_launcher.png");
        }
        // Icono 512 para la web/README
        write(legacy(disc, 512), res, "../icono-512.png");
    }

    static Rectangle alphaBox(BufferedImage im, int th) {
        int x0 = im.getWidth(), y0 = im.getHeight(), x1 = -1, y1 = -1;
        for (int y = 0; y < im.getHeight(); y++)
            for (int x = 0; x < im.getWidth(); x++)
                if ((im.getRGB(x, y) >>> 24) > th) {
                    x0 = Math.min(x0, x); y0 = Math.min(y0, y); x1 = Math.max(x1, x); y1 = Math.max(y1, y);
                }
        return new Rectangle(x0, y0, x1 - x0 + 1, y1 - y0 + 1);
    }

    static BufferedImage crop(BufferedImage im, Rectangle r) {
        int s = Math.max(r.width, r.height);
        BufferedImage o = new BufferedImage(s, s, BufferedImage.TYPE_INT_ARGB);
        Graphics2D g = o.createGraphics();
        g.drawImage(im, (s - r.width) / 2 - r.x, (s - r.height) / 2 - r.y, null);
        g.dispose();
        return o;
    }

    // blanco -> transparente; azul -> opaco (alpha = 255 - min(r,g,b))
    static BufferedImage toMark(BufferedImage im) {
        BufferedImage o = new BufferedImage(im.getWidth(), im.getHeight(), BufferedImage.TYPE_INT_ARGB);
        for (int y = 0; y < im.getHeight(); y++)
            for (int x = 0; x < im.getWidth(); x++) {
                int p = im.getRGB(x, y);
                int al = p >>> 24, r = (p >> 16) & 255, g = (p >> 8) & 255, b = p & 255;
                int m = 255 - Math.min(r, Math.min(g, b));
                int na = m * al / 255;
                o.setRGB(x, y, (na << 24) | 0x1E90D6);
            }
        return o;
    }

    static BufferedImage tint(BufferedImage im, Color c) {
        BufferedImage o = new BufferedImage(im.getWidth(), im.getHeight(), BufferedImage.TYPE_INT_ARGB);
        for (int y = 0; y < im.getHeight(); y++)
            for (int x = 0; x < im.getWidth(); x++)
                o.setRGB(x, y, (im.getRGB(x, y) & 0xff000000) | (c.getRGB() & 0xffffff));
        return o;
    }

    static BufferedImage scale(BufferedImage im, int s) {
        // escalado progresivo para buena calidad
        BufferedImage cur = im;
        while (cur.getWidth() / 2 >= s) cur = resize(cur, cur.getWidth() / 2);
        return resize(cur, s);
    }

    static BufferedImage resize(BufferedImage im, int s) {
        BufferedImage o = new BufferedImage(s, s, BufferedImage.TYPE_INT_ARGB);
        Graphics2D g = o.createGraphics();
        g.setRenderingHint(RenderingHints.KEY_INTERPOLATION, RenderingHints.VALUE_INTERPOLATION_BICUBIC);
        g.setRenderingHint(RenderingHints.KEY_RENDERING, RenderingHints.VALUE_RENDER_QUALITY);
        g.drawImage(im, 0, 0, s, s, null);
        g.dispose();
        return o;
    }

    static BufferedImage center(BufferedImage im, int canvas, int size) {
        BufferedImage o = new BufferedImage(canvas, canvas, BufferedImage.TYPE_INT_ARGB);
        Graphics2D g = o.createGraphics();
        g.drawImage(scale(im, size), (canvas - size) / 2, (canvas - size) / 2, null);
        g.dispose();
        return o;
    }

    static BufferedImage legacy(BufferedImage disc, int s) {
        int big = s * 4;
        BufferedImage o = new BufferedImage(big, big, BufferedImage.TYPE_INT_ARGB);
        Graphics2D g = o.createGraphics();
        g.setRenderingHint(RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_ON);
        g.setColor(new Color(0x1E90D6));
        g.fillOval(0, 0, big, big);
        int inner = (int) (big * 0.78);
        g.drawImage(scale(disc, inner), (big - inner) / 2, (big - inner) / 2, null);
        g.dispose();
        return scale(o, s);
    }

    static void write(BufferedImage im, File res, String rel) throws Exception {
        File f = new File(res, rel);
        f.getParentFile().mkdirs();
        ImageIO.write(im, "png", f);
        System.out.println("  " + f.getPath() + " " + im.getWidth() + "x" + im.getHeight());
    }
}
