import { BadgeCheck } from "lucide-react";


export default function VerifyMe() {
  return (
    <main className="flex min-h-screen items-center justify-center bg-[#0F172A] px-6">
      <div className="w-full max-w-md rounded-2xl border border-slate-800 bg-slate-900 p-10 text-center shadow-xl">
        <BadgeCheck className="mx-auto h-14 w-14 text-emerald-400" />

        <h1 className="mt-6 text-3xl font-bold text-white">
          Cyprian Nwakire
        </h1>

        <p className="mt-2 text-lg text-slate-300">
          Senior Software Engineer
        </p>

        <div className="mt-8 inline-flex items-center gap-2 rounded-full border border-emerald-500/30 bg-emerald-500/10 px-4 py-2">
          <BadgeCheck className="h-4 w-4 text-emerald-400" />
          <span className="text-sm font-medium text-emerald-400">
            Verified by NostraX
          </span>
        </div>
      </div>
    </main>
  );
}