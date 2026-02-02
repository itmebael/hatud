# LTO Driver Verification Email Template

## SHORT EMAIL TEMPLATES (Simple & Direct)

---

## ✅ EMAIL 1: Verification Approved (SHORT VERSION)

**Dear {{name}},**

**Subject: LTO Verification Approved**

✅ **YOU ARE NOW VERIFIED**

Your driver verification has been approved by LTO. You can now access all the features in the HATUD Driver App.

Log in to your app and go online to start accepting rides!

**HATUD Team**

---

## ❌ EMAIL 2: Verification Rejected (SHORT VERSION)

**Dear {{name}},**

**Subject: LTO Verification Rejected**

❌ **YOU ARE REJECTED**

Your driver verification has been rejected by LTO. Please go to LTO to update your information.

After updating your documents, you can resubmit your verification in the app.

**HATUD Team**

---

## Plain Text Version (Copy & Paste Ready)

### ✅ VERIFIED:
```
Dear {{name}},

Subject: LTO Verification Approved

✅ YOU ARE NOW VERIFIED

Your driver verification has been approved by LTO. You can now access all the features in the HATUD Driver App.

Log in to your app and go online to start accepting rides!

HATUD Team
```

### ❌ REJECTED:
```
Dear {{name}},

Subject: LTO Verification Rejected

❌ YOU ARE REJECTED

Your driver verification has been rejected by LTO. Please go to LTO to update your information.

After updating your documents, you can resubmit your verification in the app.

HATUD Team
```

---

## HTML Email Template (Optional - For Professional Use)

```html
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <style>
        body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
        .container { max-width: 600px; margin: 0 auto; padding: 20px; }
        .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 30px; text-align: center; border-radius: 10px 10px 0 0; }
        .content { background: #f9f9f9; padding: 30px; border: 1px solid #ddd; }
        .footer { background: #333; color: white; padding: 20px; text-align: center; border-radius: 0 0 10px 10px; font-size: 12px; }
        .button { display: inline-block; padding: 12px 30px; background: #667eea; color: white; text-decoration: none; border-radius: 5px; margin: 20px 0; }
        .info-box { background: #e3f2fd; border-left: 4px solid #2196f3; padding: 15px; margin: 20px 0; }
        .success-box { background: #e8f5e9; border-left: 4px solid #4caf50; padding: 15px; margin: 20px 0; }
        .warning-box { background: #fff3e0; border-left: 4px solid #ff9800; padding: 15px; margin: 20px 0; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>HATUD Driver Verification</h1>
            <p>Land Transportation Office</p>
        </div>
        <div class="content">
            <h2>Verification Approved ✅</h2>
            <p>Dear [Driver Name],</p>
            
            <div class="success-box">
                <strong>Congratulations!</strong><br>
                Your driver verification has been <strong>APPROVED</strong> by LTO.
            </div>
            
            <p><strong>Your Verification Details:</strong></p>
            <ul>
                <li><strong>Driver License:</strong> [License Number]</li>
                <li><strong>Tricycle Plate:</strong> [Plate Number]</li>
                <li><strong>Verification Date:</strong> [Date]</li>
            </ul>
            
            <div class="info-box">
                <strong>What You Can Do Now:</strong>
                <ul>
                    <li>✅ Go online and accept ride requests</li>
                    <li>✅ Access all driver features</li>
                    <li>✅ Start earning with HATUD</li>
                </ul>
            </div>
            
            <p><strong>Next Steps:</strong></p>
            <ol>
                <li>Log in to your HATUD Driver App</li>
                <li>Toggle your status to "Online"</li>
                <li>Start accepting rides!</li>
            </ol>
            
            <p>If you have any questions, please contact our support team.</p>
            
            <p>Thank you for being part of the HATUD family!</p>
        </div>
        <div class="footer">
            <p><strong>HATUD Tricycle App</strong></p>
            <p>LTO Verification Team</p>
            <p>© 2024 HATUD. All rights reserved.</p>
        </div>
    </div>
</body>
</html>
```

---

## Usage Instructions

1. **Replace Placeholders:**
   - `[Driver Name]` - Driver's full name
   - `[License Number]` - Driver's license number
   - `[Plate Number]` - Tricycle plate number
   - `[Date]` - Verification date
   - `[Reason]` - Rejection reason (if applicable)

2. **Customize as needed:**
   - Add your company logo
   - Update contact information
   - Adjust colors to match your brand
   - Add support contact details

3. **Send automatically:**
   - Integrate with your email service
   - Trigger when `driver_verification_status` changes to 'verified'
   - Use database triggers or app logic to send emails

---

## SQL Trigger Example (Optional)

```sql
-- Create a function to send email notification (requires email service setup)
CREATE OR REPLACE FUNCTION notify_driver_verification()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.driver_verification_status = 'verified' 
     AND OLD.driver_verification_status != 'verified' THEN
    -- Send email notification here
    -- This requires your email service integration
    RAISE NOTICE 'Driver % verified - send email to %', NEW.id, NEW.email;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger
CREATE TRIGGER driver_verification_email_trigger
AFTER UPDATE ON public.users
FOR EACH ROW
WHEN (NEW.driver_verification_status IS DISTINCT FROM OLD.driver_verification_status)
EXECUTE FUNCTION notify_driver_verification();
```

---

**Note:** Email sending functionality needs to be implemented in your backend/email service provider (e.g., SendGrid, AWS SES, SMTP, etc.)

