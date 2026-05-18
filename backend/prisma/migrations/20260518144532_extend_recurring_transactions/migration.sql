/*
  Warnings:

  - Added the required column `account_id` to the `recurring_transactions` table without a default value. This is not possible if the table is not empty.
  - Added the required column `amount` to the `recurring_transactions` table without a default value. This is not possible if the table is not empty.
  - Added the required column `name` to the `recurring_transactions` table without a default value. This is not possible if the table is not empty.
  - Added the required column `start_date` to the `recurring_transactions` table without a default value. This is not possible if the table is not empty.
  - Added the required column `type` to the `recurring_transactions` table without a default value. This is not possible if the table is not empty.
  - Added the required column `updated_at` to the `recurring_transactions` table without a default value. This is not possible if the table is not empty.

*/
-- AlterTable
ALTER TABLE "recurring_transactions" ADD COLUMN     "account_id" TEXT NOT NULL,
ADD COLUMN     "amount" DECIMAL(18,2) NOT NULL,
ADD COLUMN     "category_id" TEXT,
ADD COLUMN     "description" TEXT,
ADD COLUMN     "end_date" TIMESTAMP(3),
ADD COLUMN     "last_run_date" TIMESTAMP(3),
ADD COLUMN     "name" TEXT NOT NULL,
ADD COLUMN     "start_date" TIMESTAMP(3) NOT NULL,
ADD COLUMN     "type" "TransactionType" NOT NULL,
ADD COLUMN     "updated_at" TIMESTAMP(3) NOT NULL;

-- AddForeignKey
ALTER TABLE "recurring_transactions" ADD CONSTRAINT "recurring_transactions_account_id_fkey" FOREIGN KEY ("account_id") REFERENCES "accounts"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "recurring_transactions" ADD CONSTRAINT "recurring_transactions_category_id_fkey" FOREIGN KEY ("category_id") REFERENCES "categories"("id") ON DELETE SET NULL ON UPDATE CASCADE;
